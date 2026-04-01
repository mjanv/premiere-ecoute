// AIDEV-NOTE: AudioWorklet processor — runs in the audio thread.
// Per 30ms frame computes: RMS VAD + spectral flatness + attack ratio.
// Classification: isSpeech (VAD gate) + isCleanSpeech (flatness + attack filter).

const SAMPLE_RATE = 16000;
const CHUNK_SAMPLES = SAMPLE_RATE * 0.5;  // 500ms chunks
const FRAME_SAMPLES = SAMPLE_RATE * 0.03; // 30ms = 480 samples
const FFT_SIZE = 512;                      // next power of 2 >= 480

// VAD hysteresis
const SPEECH_ON   = 0.008;
const SPEECH_OFF  = 0.003;
const HANG_FRAMES = 20;    // ~1s hangover

// Speech quality thresholds
const FLATNESS_MAX  = 0.4;  // above → broadband noise
const ATTACK_MAX    = 4.0;  // above → transient (click/thump)
const ATTACK_SPLIT  = Math.floor(FRAME_SAMPLES * 5 / 30); // first 5ms of the 30ms frame

// --- Radix-2 Cooley-Tukey FFT (in-place, real input via split re/im arrays) ---
function fft(re, im) {
  const n = re.length;
  // Bit-reversal permutation
  let j = 0;
  for (let i = 1; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) {
      [re[i], re[j]] = [re[j], re[i]];
      [im[i], im[j]] = [im[j], im[i]];
    }
  }
  // Butterfly stages
  for (let len = 2; len <= n; len <<= 1) {
    const ang = -2 * Math.PI / len;
    const wRe = Math.cos(ang), wIm = Math.sin(ang);
    for (let i = 0; i < n; i += len) {
      let curRe = 1, curIm = 0;
      for (let k = 0; k < len / 2; k++) {
        const uRe = re[i + k], uIm = im[i + k];
        const vRe = re[i + k + len/2] * curRe - im[i + k + len/2] * curIm;
        const vIm = re[i + k + len/2] * curIm + im[i + k + len/2] * curRe;
        re[i + k]         = uRe + vRe;
        im[i + k]         = uIm + vIm;
        re[i + k + len/2] = uRe - vRe;
        im[i + k + len/2] = uIm - vIm;
        const newRe = curRe * wRe - curIm * wIm;
        curIm = curRe * wIm + curIm * wRe;
        curRe = newRe;
      }
    }
  }
}

// Spectral flatness (Wiener entropy): geometric_mean(|X|) / arithmetic_mean(|X|)
// Returns 0 (tonal/speech) → 1 (flat/noise)
function spectralFlatness(re, im) {
  const half = FFT_SIZE / 2;
  let logSum = 0, linSum = 0;
  for (let i = 1; i < half; i++) {
    const mag = Math.sqrt(re[i] * re[i] + im[i] * im[i]) + 1e-10;
    logSum += Math.log(mag);
    linSum += mag;
  }
  const n = half - 1;
  return Math.exp(logSum / n) / (linSum / n);
}

// Attack ratio: energy in first 5ms vs rest of frame — high = transient
function attackRatio(samples, offset) {
  let eAttack = 0, eBody = 0;
  const splitAt = offset + ATTACK_SPLIT;
  const end = Math.min(offset + FRAME_SAMPLES, samples.length);
  for (let i = offset; i < splitAt && i < end; i++) eAttack += samples[i] * samples[i];
  for (let i = splitAt; i < end; i++) eBody += samples[i] * samples[i];
  return eBody < 1e-10 ? 0 : eAttack / (eBody + 1e-10);
}

class PcmProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    // AIDEV-NOTE: Ring buffer — avoids push() + slice() + copy on every chunk flush.
    this._ring = new Float32Array(CHUNK_SAMPLES);
    this._writePos = 0;
    this._count = 0;
    this._speechActive = false;
    this._hangCount = 0;
    // Reusable FFT buffers
    this._re = new Float64Array(FFT_SIZE);
    this._im = new Float64Array(FFT_SIZE);
    // Reusable chunk output buffer (transferred to main thread via postMessage)
    this._chunk = new Float32Array(CHUNK_SAMPLES);
  }

  process(inputs) {
    const input = inputs[0];
    if (!input || !input[0]) return true;

    const channel = input[0];
    for (let i = 0; i < channel.length; i++) {
      this._ring[this._writePos] = channel[i];
      this._writePos = (this._writePos + 1) % CHUNK_SAMPLES;
      this._count++;
    }

    if (this._count >= CHUNK_SAMPLES) {
      // Linearise ring buffer into _chunk without allocation
      const split = this._writePos; // oldest sample is at writePos (ring just wrapped)
      this._chunk.set(this._ring.subarray(split));
      this._chunk.set(this._ring.subarray(0, split), CHUNK_SAMPLES - split);

      const frames = this._computeFrames(this._chunk);
      // Transfer a copy — _chunk is reused next flush
      const samples = this._chunk.slice();
      this.port.postMessage({ samples, frames });
      this._count = 0;
    }

    return true;
  }

  _computeFrames(samples) {
    const frames = [];

    for (let i = 0; i < samples.length; i += FRAME_SAMPLES) {
      const end = Math.min(i + FRAME_SAMPLES, samples.length);
      const frameLen = end - i;

      // --- RMS ---
      let sum = 0;
      for (let j = i; j < end; j++) sum += samples[j] * samples[j];
      const rms = Math.sqrt(sum / frameLen);

      // --- VAD gate ---
      if (rms >= SPEECH_ON) {
        this._speechActive = true;
        this._hangCount = HANG_FRAMES;
      } else if (this._hangCount > 0) {
        this._hangCount--;
      } else {
        this._speechActive = false;
      }

      // --- Spectral flatness via FFT (only when VAD active — saves CPU) ---
      let flatness = 0;
      let attack = 0;
      if (this._speechActive) {
        // Fill FFT input with Hann-windowed frame, zero-pad to FFT_SIZE
        this._re.fill(0);
        this._im.fill(0);
        for (let j = 0; j < frameLen; j++) {
          const w = 0.5 * (1 - Math.cos(2 * Math.PI * j / (frameLen - 1)));
          this._re[j] = samples[i + j] * w;
        }
        fft(this._re, this._im);
        flatness = spectralFlatness(this._re, this._im);
        attack = attackRatio(samples, i);
      }

      const isCleanSpeech = this._speechActive
        && flatness < FLATNESS_MAX
        && attack < ATTACK_MAX;

      frames.push({ rms, isSpeech: this._speechActive, isCleanSpeech, flatness, attack });
    }

    return frames;
  }
}

registerProcessor("pcm-processor", PcmProcessor);
