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
    this.recording = false;
    this.SAMPLES_PER_PX = 133; // ~10s visible at 16kHz on a 1200px canvas

    this.el.width = this.el.parentElement.clientWidth;
    this.el.height = 160;
    this.ctx = this.el.getContext("2d");
    this.clearCanvas();

    this.el.addEventListener("microphone:toggle", () => {
      if (this.recording) this.stopRecording(); else this.startRecording();
    });
  },

  destroyed() {
    this.stopRecording();
  },

  startRecording() {
    this.allSamples = new Float32Array(0);
    this.recording = true;
    this.clearCanvas();

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
    // Redraw so the waveform stays visible after stopping
    if (this.allSamples.length > 0) this.drawWaveform(this.allSamples);
  },

  // Fixed-width canvas, scrolling window — always shows the most recent audio.
  // No canvas resize ever, so no flicker.
  drawWaveform(samples) {
    const S = this.SAMPLES_PER_PX;
    const w = this.el.width;
    const h = this.el.height;
    const mid = h / 2;

    // How many samples fit in the canvas
    const visibleSamples = w * S;
    const startSample = Math.max(0, samples.length - visibleSamples);
    const startCol = Math.floor(startSample / S);
    const totalCols = Math.ceil(samples.length / S);
    const displayCols = totalCols - startCol;

    this.ctx.fillStyle = "#111827";
    this.ctx.fillRect(0, 0, w, h);

    this.ctx.strokeStyle = "#1f2937";
    this.ctx.lineWidth = 1;
    this.ctx.beginPath();
    this.ctx.moveTo(0, mid);
    this.ctx.lineTo(w, mid);
    this.ctx.stroke();

    this.ctx.strokeStyle = "#6366f1";
    this.ctx.lineWidth = 1;
    for (let i = 0; i < displayCols; i++) {
      const col = startCol + i;
      const s0 = col * S, s1 = Math.min(s0 + S, samples.length);
      let min = 0, max = 0;
      for (let j = s0; j < s1; j++) {
        if (samples[j] < min) min = samples[j];
        if (samples[j] > max) max = samples[j];
      }
      this.ctx.beginPath();
      this.ctx.moveTo(i + 0.5, mid - max * mid);
      this.ctx.lineTo(i + 0.5, mid - min * mid || mid + 1);
      this.ctx.stroke();
    }

    // Playhead at right edge of data
    const playheadX = Math.min(displayCols, w - 1);
    this.ctx.strokeStyle = "#ef4444";
    this.ctx.beginPath();
    this.ctx.moveTo(playheadX + 0.5, 0);
    this.ctx.lineTo(playheadX + 0.5, h);
    this.ctx.stroke();
  },

  clearCanvas() {
    const w = this.el.width;
    const h = this.el.height;
    this.ctx.fillStyle = "#111827";
    this.ctx.fillRect(0, 0, w, h);
    this.ctx.strokeStyle = "#1f2937";
    this.ctx.lineWidth = 1;
    this.ctx.beginPath();
    this.ctx.moveTo(0, h / 2);
    this.ctx.lineTo(w, h / 2);
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
