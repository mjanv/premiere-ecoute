// AIDEV-NOTE: AudioWorklet processor — runs in the audio thread.
// Accumulates PCM into CHUNK_SAMPLES chunks, computes per-frame RMS VAD,
// and posts {samples, frames} where frames = [{rms, isSpeech}] at 30ms resolution.

const SAMPLE_RATE = 16000;
const CHUNK_SAMPLES = SAMPLE_RATE * 0.5;  // 500ms chunks
const FRAME_SAMPLES = SAMPLE_RATE * 0.03; // 30ms VAD frames

// Hysteresis thresholds — tune for clean close-mic
const SPEECH_ON  = 0.008; // RMS to open speech gate
const SPEECH_OFF = 0.003; // RMS to close speech gate
const HANG_FRAMES = 33;   // ~1s hangover at 30ms frames — long tail, avoids cutting words

class PcmProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this._buffer = [];
    this._count = 0;
    this._speechActive = false;
    this._hangCount = 0;
  }

  process(inputs) {
    const input = inputs[0];
    if (!input || !input[0]) return true;

    const channel = input[0];
    for (let i = 0; i < channel.length; i++) {
      this._buffer.push(channel[i]);
      this._count++;
    }

    if (this._count >= CHUNK_SAMPLES) {
      const samples = new Float32Array(this._buffer);
      const frames = this._computeVadFrames(samples);
      this.port.postMessage({ samples, frames });
      this._buffer = [];
      this._count = 0;
    }

    return true;
  }

  _computeVadFrames(samples) {
    const frames = [];
    for (let i = 0; i < samples.length; i += FRAME_SAMPLES) {
      const end = Math.min(i + FRAME_SAMPLES, samples.length);
      let sum = 0;
      for (let j = i; j < end; j++) sum += samples[j] * samples[j];
      const rms = Math.sqrt(sum / (end - i));

      if (rms >= SPEECH_ON) {
        this._speechActive = true;
        this._hangCount = HANG_FRAMES;
      } else if (this._hangCount > 0) {
        this._hangCount--;
        // Keep speechActive = true during hang
      } else {
        this._speechActive = false;
      }

      frames.push({ rms, isSpeech: this._speechActive });
    }
    return frames;
  }
}

registerProcessor("pcm-processor", PcmProcessor);
