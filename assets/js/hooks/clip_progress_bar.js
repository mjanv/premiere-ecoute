// ClipProgressBar hook — a click-to-seek progress bar rendered as a plain div
// (not <input type="range">, which fights LiveView's re-rendering of live form
// element state). The fill width is driven by a local clock that advances
// smoothly between server updates (once per second, from the overlay's
// YoutubePlayer poll) and resyncs whenever a fresh update() lands, correcting
// any drift. Clicking anywhere on the bar computes the target second from the
// click position and pushes a "seek" event up to the LiveComponent.
export const ClipProgressBar = {
  mounted() {
    this._tick = this._tick.bind(this);
    this._readData();
    this._startClock();

    this.el.addEventListener("click", (event) => {
      if (!this._duration) return;

      const rect = this.el.getBoundingClientRect();
      const ratio = Math.min(1, Math.max(0, (event.clientX - rect.left) / rect.width));
      this.pushEventTo(this.el, "clip_seek", { position: Math.round(ratio * this._duration) });
    });
  },

  updated() {
    this._readData();
  },

  destroyed() {
    if (this._rafId) cancelAnimationFrame(this._rafId);
  },

  _readData() {
    this._current = parseFloat(this.el.dataset.current) || 0;
    this._duration = parseFloat(this.el.dataset.duration) || 0;
    this._syncedAt = Date.now();
    this._render();
  },

  _startClock() {
    this._rafId = requestAnimationFrame(this._tick);
  },

  _tick() {
    this._render();
    this._rafId = requestAnimationFrame(this._tick);
  },

  _render() {
    const elapsedSinceSync = (Date.now() - this._syncedAt) / 1000;
    const estimatedCurrent = Math.min(this._current + elapsedSinceSync, this._duration || Infinity);
    const ratio = this._duration ? estimatedCurrent / this._duration : 0;

    const fill = this.el.querySelector('[data-role="fill"]');
    if (fill) fill.style.width = `${Math.min(100, Math.max(0, ratio * 100))}%`;
  },
};
