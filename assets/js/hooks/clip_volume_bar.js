// ClipVolumeBar hook — a click-to-set volume bar, same plain-div style as
// ClipProgressBar (not <input type="range">, which fights LiveView's
// re-rendering of live form element state). No local clock needed since
// volume doesn't advance on its own — just renders the last known value and
// updates it locally on click for instant visual feedback.
export const ClipVolumeBar = {
  mounted() {
    this._render(parseFloat(this.el.dataset.volume) || 0);

    this.el.addEventListener("click", (event) => {
      const rect = this.el.getBoundingClientRect();
      const ratio = Math.min(1, Math.max(0, (event.clientX - rect.left) / rect.width));
      const volume = Math.round(ratio * 100);

      this._render(volume);
      this.pushEventTo(this.el, "clip_volume", { volume });
    });
  },

  updated() {
    this._render(parseFloat(this.el.dataset.volume) || 0);
  },

  _render(volume) {
    const fill = this.el.querySelector('[data-role="fill"]');
    if (fill) fill.style.width = `${Math.min(100, Math.max(0, volume))}%`;
  },
};
