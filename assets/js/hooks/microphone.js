// AIDEV-NOTE: Hook for audio recording + waveform visualisation used by AudioLive.
//
// Uses AudioWorklet (pcm-processor.js) to capture raw PCM directly from the audio
// thread, avoiding MediaRecorder container format issues. Every CHUNK_SAMPLES frames
// the worklet posts samples to the main thread → waveform accumulates + server notified.

const SAMPLING_RATE = 16_000;

export const Microphone = {
  mounted() {
    this.audioCtx = null;
    this.stream = null;
    this.allSamples = new Float32Array(0);
    this.animationId = null;
    this.recording = false;

    /** @type {CanvasRenderingContext2D} */
    this.ctx = this.el.getContext("2d");
    this.clearCanvas();

    this.el.addEventListener("microphone:toggle", () => {
      if (this.recording) {
        this.stopRecording();
      } else {
        this.startRecording();
      }
    });
  },

  destroyed() {
    this.stopRecording();
  },

  startRecording() {
    this.allSamples = new Float32Array(0);
    this.recording = true;

    navigator.mediaDevices.getUserMedia({ audio: true }).then(async (stream) => {
      this.stream = stream;
      this.audioCtx = new AudioContext({ sampleRate: SAMPLING_RATE });

      await this.audioCtx.audioWorklet.addModule("/assets/pcm-processor.js");

      const source = this.audioCtx.createMediaStreamSource(stream);
      const worklet = new AudioWorkletNode(this.audioCtx, "pcm-processor");

      worklet.port.onmessage = (event) => {
        if (!this.recording) return;
        const newSamples = event.data.samples;

        // Accumulate
        const merged = new Float32Array(this.allSamples.length + newSamples.length);
        merged.set(this.allSamples);
        merged.set(newSamples, this.allSamples.length);
        this.allSamples = merged;

        this.drawWaveform(this.allSamples);

        const endianness = this.el.dataset.endianness;
        const converted = this.convertEndianness32(newSamples.buffer, this.getEndianness(), endianness);
        const bytes = new Uint8Array(converted);
        let binary = "";
        for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
        this.pushEvent("audio_chunk", { data: btoa(binary) });
      };

      source.connect(worklet);
      worklet.connect(this.audioCtx.destination);
      this.worklet = worklet;
      this.source = source;

      this.pushEvent("recording_started", {});
    });
  },

  stopRecording() {
    this.recording = false;
    if (this.source) { this.source.disconnect(); this.source = null; }
    if (this.worklet) { this.worklet.disconnect(); this.worklet = null; }
    if (this.audioCtx) { this.audioCtx.close(); this.audioCtx = null; }
    if (this.stream) { this.stream.getTracks().forEach((t) => t.stop()); this.stream = null; }
    this.pushEvent("recording_stopped", {});
  },

  // Draw the exact PCM samples — one pixel column per downsampled bucket
  drawWaveform(samples) {
    const { width, height } = this.el;
    const mid = height / 2;

    this.ctx.fillStyle = "#111827";
    this.ctx.fillRect(0, 0, width, height);

    this.ctx.lineWidth = 1.5;
    this.ctx.strokeStyle = "#6366f1";
    this.ctx.beginPath();

    const bucketSize = Math.max(1, Math.floor(samples.length / width));

    for (let col = 0; col < width; col++) {
      const start = col * bucketSize;
      const end = Math.min(start + bucketSize, samples.length);

      // Find min/max in the bucket to preserve peaks
      let min = 0, max = 0;
      for (let i = start; i < end; i++) {
        if (samples[i] < min) min = samples[i];
        if (samples[i] > max) max = samples[i];
      }

      const yTop = mid - max * mid;
      const yBot = mid - min * mid;

      if (col === 0) {
        this.ctx.moveTo(col, yTop);
      } else {
        this.ctx.lineTo(col, yTop);
        this.ctx.lineTo(col, yBot);
      }
    }

    this.ctx.stroke();
  },

  clearCanvas() {
    const { width, height } = this.el;
    this.ctx.fillStyle = "#111827";
    this.ctx.fillRect(0, 0, width, height);

    this.ctx.lineWidth = 1.5;
    this.ctx.strokeStyle = "#374151";
    this.ctx.beginPath();
    this.ctx.moveTo(0, height / 2);
    this.ctx.lineTo(width, height / 2);
    this.ctx.stroke();
  },

  convertEndianness32(buffer, from, to) {
    if (from === to) return buffer;

    const view = new DataView(buffer);
    for (let i = 0; i < buffer.byteLength; i += 4) {
      const b0 = view.getUint8(i);
      const b1 = view.getUint8(i + 1);
      const b2 = view.getUint8(i + 2);
      const b3 = view.getUint8(i + 3);
      view.setUint8(i, b3);
      view.setUint8(i + 1, b2);
      view.setUint8(i + 2, b1);
      view.setUint8(i + 3, b0);
    }
    return buffer;
  },

  getEndianness() {
    const buffer = new ArrayBuffer(2);
    const int16Array = new Uint16Array(buffer);
    const int8Array = new Uint8Array(buffer);
    int16Array[0] = 1;
    return int8Array[0] === 1 ? "little" : "big";
  },
};
