// Halftone grain over the session overlay colours, after the "20" and "26" block
// letters of priv/demos/poster-flipbook.html: a staggered grid of small dark squares
// (every other row shifted by half a step), each jittered and some left out, so the
// grain has no regular period (a regular grid gives moiré when OBS rescales). The
// canvas is blended with `mix-blend-mode: multiply`, so it darkens any colour by the
// same share, whatever the user's primary colour is, and leaves black untouched.
// Elements marked `data-grain-exclude` keep their colours: their inner box (inside
// the border) is cleared from the grain.
import { clamp01, onResize } from "./overlay_canvas";

// Tuning knobs
const ROWS = 220; // dot rows across the widget height (step = height / ROWS)
const DOT = 0.5; // dot side, as a share of the step
const DARKEN = 0.25; // how much a dot darkens the colour under it on average (0..1)
const VARIANCE = 0.8; // random spread of each dot's darkness around DARKEN (0 = all equal)
const JITTER = 0.7; // random offset of each dot, as a share of the step
const GAPS = 0.15; // share of dots left out

// Grey levels around DARKEN, so the grain is gritty rather than uniform.
const GREYS = Array.from({ length: 16 }, (_, i) => {
  const v = Math.round(255 * (1 - clamp01(DARKEN * (1 + VARIANCE * (i / 15 - 0.5) * 2))));
  return `rgb(${v},${v},${v})`;
});

function draw(canvas, ratio) {
  const w = canvas.width;
  const h = canvas.height;
  const ctx = canvas.getContext("2d");
  const step = Math.max(2, h / ROWS);
  const size = Math.max(1, step * DOT);

  ctx.clearRect(0, 0, w, h);
  for (let row = 0, y = 0; y < h; row++, y += step) {
    for (let x = (row % 2) * (step / 2); x < w; x += step) {
      if (Math.random() < GAPS) continue;
      ctx.fillStyle = GREYS[(Math.random() * GREYS.length) | 0];
      const jx = (Math.random() - 0.5) * step * JITTER;
      const jy = (Math.random() - 0.5) * step * JITTER;
      ctx.fillRect(Math.round(x + jx), Math.round(y + jy), size, size);
    }
  }

  const box = canvas.getBoundingClientRect();
  const root = canvas.closest("[data-overlay-root]") || canvas.parentElement;
  for (const el of root.querySelectorAll("[data-grain-exclude]")) {
    const r = el.getBoundingClientRect();
    ctx.clearRect(
      (r.left - box.left + el.clientLeft) * ratio,
      (r.top - box.top + el.clientTop) * ratio,
      el.clientWidth * ratio,
      el.clientHeight * ratio,
    );
  }
}

export const HalftoneGrain = {
  mounted() {
    this.observer = onResize(this.el, (ratio) => draw(this.el, ratio));
  },
  destroyed() {
    this.observer?.disconnect();
  },
};
