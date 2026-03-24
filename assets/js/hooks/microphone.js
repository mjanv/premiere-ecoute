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

    const h = 160;
    const w = Math.floor(this.el.parentElement.getBoundingClientRect().width);
    this.W = w;
    this.H = h;
    this.el.width = w;
    this.el.height = h;
    this.el.style.cssText = `width:${w}px;height:${h}px;display:block;`;
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
    this.allFrames = [];
    this.totalFrames = 0;      // absolute frame counter since recording start
    this.segmentStart = null;        // absolute frame index where current speech segment started
    this.segmentStartFrameIdx = null; // index into allFrames where segment started
    this.segmentSamples = [];        // raw Float32 samples accumulated for current segment
    this.recording = true;

    navigator.mediaDevices.getUserMedia({ audio: true }).then(async (stream) => {
      this.stream = stream;
      this.audioCtx = new AudioContext({ sampleRate: SAMPLING_RATE });

      await this.audioCtx.audioWorklet.addModule("/assets/pcm-processor.js");

      const source = this.audioCtx.createMediaStreamSource(stream);
      const worklet = new AudioWorkletNode(this.audioCtx, "pcm-processor");

      worklet.port.onmessage = (event) => {
        if (!this.recording) return;
        const { samples: newSamples, frames: newFrames } = event.data;

        // Keep only the visible window of samples — no unbounded growth
        const maxSamples = this.W * this.SAMPLES_PER_PX;
        const combined = new Float32Array(this.allSamples.length + newSamples.length);
        combined.set(this.allSamples);
        combined.set(newSamples, this.allSamples.length);
        this.allSamples = combined.length > maxSamples
          ? combined.slice(combined.length - maxSamples)
          : combined;

        // Append new frames first so smoothedClean has full context
        let framesOffsetBeforeAppend = this.allFrames.length;
        for (let i = 0; i < newFrames.length; i++) this.allFrames.push(newFrames[i]);
        const maxFrames = Math.ceil(maxSamples / 480);
        if (this.allFrames.length > maxFrames) {
          const evicted = this.allFrames.length - maxFrames;
          this.allFrames.splice(0, evicted);
          framesOffsetBeforeAppend = Math.max(0, framesOffsetBeforeAppend - evicted);
          if (this.segmentStartFrameIdx !== null) {
            this.segmentStartFrameIdx = Math.max(0, this.segmentStartFrameIdx - evicted);
          }
        }

        // Detect completed segments (speech → silence transitions)
        // AIDEV-NOTE: is_clean is evaluated post-hoc at segment close via a full pass over
        // allFrames — avoids stale context from incremental smoothedClean calls mid-chunk.
        const FRAME_MS = 30;
        const completedSegments = [];
        for (let i = 0; i < newFrames.length; i++) {
          const absFrame = this.totalFrames + i;
          if (newFrames[i].isSpeech && this.segmentStart === null) {
            this.segmentStart = absFrame;
            this.segmentStartFrameIdx = framesOffsetBeforeAppend + i;
            this.segmentSamples = [];
          }
          // Accumulate samples for the current open segment (speech + hangover)
          if (this.segmentStart !== null) {
            const fStart = i * 480, fEnd = Math.min(fStart + 480, newSamples.length);
            for (let s = fStart; s < fEnd; s++) this.segmentSamples.push(newSamples[s]);
          }
          if (!newFrames[i].isSpeech && this.segmentStart !== null) {
            // Post-hoc pass: evaluate smoothed clean over the segment's frames in allFrames
            const segEndFrameIdx = framesOffsetBeforeAppend + i;
            let cleanCount = 0, totalCount = 0;
            for (let f = this.segmentStartFrameIdx; f < segEndFrameIdx && f < this.allFrames.length; f++) {
              if (this.allFrames[f].rms >= 0.006) {
                if (this.smoothedClean(this.allFrames, f)) cleanCount++;
                totalCount++;
              }
            }
            const cleanRatio = totalCount > 0 ? cleanCount / totalCount : 0;
            completedSegments.push({
              start_ms: this.segmentStart * FRAME_MS,
              end_ms: absFrame * FRAME_MS,
              is_clean: cleanRatio > 0.5,
              samples: new Float32Array(this.segmentSamples)
            });
            this.segmentStart = null;
            this.segmentStartFrameIdx = null;
            this.segmentSamples = [];
          }
        }
        this.totalFrames += newFrames.length;

        this.drawWaveform(this.allSamples, this.allFrames);

        const endianness = this.el.dataset.endianness;
        const converted = this.convertEndianness32(newSamples.buffer, this.getEndianness(), endianness);
        const bytes = new Uint8Array(converted);
        let binary = "";
        for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
        this.pushEvent("audio_chunk", { data: btoa(binary) });
        for (const seg of completedSegments) {
          if (seg.samples) {
            const bytes = new Uint8Array(seg.samples.buffer);
            let binary = "";
            for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
            seg.audio = btoa(binary);
            delete seg.samples;
          }
          this.pushEvent("segment_detected", seg);
        }
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
    if (this.allSamples.length > 0) this.drawWaveform(this.allSamples, this.allFrames);
  },

  // AIDEV-NOTE: Majority-vote smoothing over ±SMOOTH_HALF frames for isCleanSpeech.
  // Absorbs short noisy bursts (plosives, fricatives) inside speech segments.
  // Only counts frames above RMS_MIN — hangover-tail frames (near-silence) are excluded
  // to avoid garbage flatness/attack values skewing the segment classification.
  smoothedClean(frames, idx, half = 3) {
    const RMS_MIN = 0.006;
    let clean = 0, total = 0;
    for (let f = Math.max(0, idx - half); f <= Math.min(frames.length - 1, idx + half); f++) {
      // Only count frames that are active speech with enough energy — excludes silence
      // neighbours and hangover-tail frames from biasing the vote
      if (frames[f].isSpeech && frames[f].rms >= RMS_MIN) {
        if (frames[f].isCleanSpeech) clean++;
        total++;
      }
    }
    // If no qualifying neighbours, fall back to the frame itself (avoids false noisy on isolated frames)
    if (total === 0 && frames[idx] && frames[idx].rms >= RMS_MIN) {
      return frames[idx].isCleanSpeech;
    }
    return total > 0 && clean / total > 0.5;
  },

  // Fixed-width canvas, scrolling window — always shows the most recent audio.
  // No canvas resize ever, so no flicker.
  // AIDEV-NOTE: h is split: top 140px = waveform, bottom 16px = VAD segment bar
  drawWaveform(samples, frames = []) {
    const S = this.SAMPLES_PER_PX;
    const FRAME_SAMPLES = 480; // 30ms at 16kHz — must match pcm-processor.js
    const w = this.W;
    const h = this.H;
    const waveH = h - 16;  // waveform area height
    const mid = waveH / 2;

    const visibleSamples = w * S;
    const startSample = Math.max(0, samples.length - visibleSamples);
    const startCol = Math.floor(startSample / S);
    const totalCols = Math.ceil(samples.length / S);
    const displayCols = Math.min(totalCols - startCol, w);

    // Background
    this.ctx.fillStyle = "#111827";
    this.ctx.fillRect(0, 0, w, h);

    // Center line
    this.ctx.strokeStyle = "#1f2937";
    this.ctx.lineWidth = 1;
    this.ctx.beginPath();
    this.ctx.moveTo(0, mid);
    this.ctx.lineTo(w, mid);
    this.ctx.stroke();

    // VAD segment bar (bottom 16px)
    // Each pixel column maps to a sample range → find corresponding frames
    const SAMPLES_PER_FRAME = FRAME_SAMPLES;
    for (let i = 0; i < displayCols; i++) {
      const s0 = (startCol + i) * S;
      const s1 = s0 + S;
      const f0 = Math.floor(s0 / SAMPLES_PER_FRAME);
      const f1 = Math.ceil(s1 / SAMPLES_PER_FRAME);
      let speechCount = 0, total = 0;
      for (let f = f0; f < f1 && f < frames.length; f++) {
        if (frames[f].isSpeech) speechCount++;
        total++;
      }
      const isSpeech = total > 0 && speechCount / total > 0.5;
      let color = "#1f2937"; // silence
      if (isSpeech) {
        const midFrame = Math.floor((f0 + f1) / 2);
        const mf = midFrame < frames.length ? frames[midFrame] : null;
        const isHangover = mf && mf.rms < 0.006;
        color = isHangover ? "#ef4444" : (this.smoothedClean(frames, midFrame) ? "#22c55e" : "#eab308");
      }
      this.ctx.fillStyle = color;
      this.ctx.fillRect(i, waveH + 2, 1, 12);
    }

    // Waveform bars
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

    // Playhead
    const playheadX = Math.min(displayCols, w - 1);
    this.ctx.strokeStyle = "#ef4444";
    this.ctx.lineWidth = 1;
    this.ctx.beginPath();
    this.ctx.moveTo(playheadX + 0.5, 0);
    this.ctx.lineTo(playheadX + 0.5, waveH);
    this.ctx.stroke();
  },

  clearCanvas() {
    const w = this.W || this.el.width;
    const h = this.H || this.el.height;
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
