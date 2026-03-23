// AIDEV-NOTE: AudioWorklet processor — runs in the audio thread.
// Accumulates raw float32 PCM samples and posts them to the main thread
// every CHUNK_SAMPLES frames for waveform drawing and server upload.

const CHUNK_SAMPLES = 16000 * 2; // 2 seconds at 16 kHz

class PcmProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this._buffer = [];
    this._count = 0;
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
      this.port.postMessage({ samples: new Float32Array(this._buffer) });
      this._buffer = [];
      this._count = 0;
    }

    return true;
  }
}

registerProcessor("pcm-processor", PcmProcessor);
