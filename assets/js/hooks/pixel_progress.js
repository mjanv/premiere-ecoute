// Pixel-cell progress bar for the session overlay, after the "flower" bursts of
// priv/demos/poster-flipbook.html: every cell is a tiny pixel pattern.
// - Played cells: a base with two diagonal half-size squares (either diagonal,
//   sometimes a solid cell), in tints of the played colour. The texture is strongest
//   at the front and fades to the flat played colour towards the start; it also
//   fades out over the end of the track, so a finished bar is flat.
// - Remaining cells: shades of the remaining colour, most with two small dark notches.
// Shades come from smooth noise plus per-cell jitter, so colours form patches, and
// the front column is dithered row by row, so the bar ends in a ragged pixel edge.
// The element carries data-percent, data-played and data-remaining (any CSS colour),
// and data-shiny in great mode.
import { clamp01, fitCanvas, rand, rgb } from "./overlay_canvas";

// Tuning knobs
const ROWS = 5; // cell rows across the bar height (few, so cells stay visible on a small widget)
const PATCH = 5; // size of the colour patches, in cells (smooth noise scale)
const JITTER = 0.35; // per-cell randomness added on top of the patches (0..1)
const FLAT = [0.05, 0.45]; // distance behind the front (share of the bar) where the texture fades out to flat colour
const SETTLE = [0.7, 1]; // progress over which the whole texture fades out, so a finished bar is flat

// Palettes from darkest to lightest, as mixes of the base colour (negative towards
// black, positive towards white); a cell picks along them with its shade.
const PALETTES = {
  normal: {
    base: [-0.08, 0, 0, 0.15, 0.3],
    square: [0.05, 0.15, 0.25, 0.38, 0.5],
    remaining: [-0.12, -0.05, 0, 0.25, 0.5],
    notch: [-0.35, -0.25, -0.18],
  },
  // Great mode: the played colour is white and the widget is multiplied by a
  // gradient, so played cells use greys. They become darker and lighter tones of the
  // gradient and stand out from the borders, which are the plain gradient.
  shiny: {
    base: [-0.55, -0.45, -0.35, -0.25, -0.15],
    square: [-0.3, -0.15, 0, 0, 0],
    remaining: [-0.05, 0, 0.1, 0.2, 0.3],
    notch: [-0.3, -0.2, -0.12],
  },
};

// Smooth value noise over cells, so neighbouring cells share a shade (patches).
function noise(x, y, seed) {
  const ix = Math.floor(x);
  const iy = Math.floor(y);
  const sx = (x - ix) * (x - ix) * (3 - 2 * (x - ix));
  const sy = (y - iy) * (y - iy) * (3 - 2 * (y - iy));
  const a = rand(ix, iy, seed);
  const b = rand(ix + 1, iy, seed);
  const c = rand(ix, iy + 1, seed);
  const d = rand(ix + 1, iy + 1, seed);
  return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy;
}

// Shade of a cell, 0..1: a patch value with some per-cell jitter.
function shade(gx, gy, seed) {
  const v = noise(gx / PATCH, gy / PATCH, seed) * (1 - JITTER) + rand(gx, gy, seed + 7) * JITTER;
  return Math.min(0.999, clamp01(v));
}

function mix([r, g, b], amount) {
  const target = amount < 0 ? 0 : 255;
  const k = Math.abs(amount);
  return `rgb(${[r, g, b].map((v) => Math.round(v + (target - v) * k)).join(",")})`;
}

function colours(el, shiny) {
  const played = rgb(el.dataset.played);
  const remaining = rgb(el.dataset.remaining);
  const { base, square, remaining: rest, notch } = PALETTES[shiny ? "shiny" : "normal"];
  return {
    base: base.map((k) => mix(played, k)),
    square: square.map((k) => mix(played, k)),
    remaining: rest.map((k) => mix(remaining, k)),
    notch: notch.map((k) => mix(remaining, k)),
  };
}

const pick = (list, v) => list[Math.floor(v * list.length)];

// Texture strength of a played cell, 0 (flat colour) to 1: full near the front,
// fading towards the start and over the end of the track. Always 1 in great mode.
function strength(behind, progress, shiny) {
  if (shiny) return 1;
  const settle = 1 - clamp01((progress - SETTLE[0]) / (SETTLE[1] - SETTLE[0]));
  return settle * (1 - clamp01((behind - FLAT[0]) / (FLAT[1] - FLAT[0])));
}

function draw(el, canvas) {
  fitCanvas(canvas);
  const ctx = canvas.getContext("2d");
  const w = canvas.width;
  const h = canvas.height;
  const shiny = "shiny" in el.dataset; // HEEx renders a true boolean attribute bare
  const palette = colours(el, shiny);

  const cell = h / ROWS;
  const half = cell / 2;
  const cols = Math.ceil(w / cell);
  // Over whole columns, so 100% fills the last, partly visible one too.
  const progress = clamp01((Number(el.dataset.percent) || 0) / 100);
  const full = Math.floor(progress * cols);
  const part = progress * cols - full;
  const box = (x, y, s) => ctx.fillRect(Math.round(x), Math.round(y), Math.ceil(s), Math.ceil(s));

  // Base colour, then two half-size squares on a diagonal (or a solid square).
  const played = (gx, gy, x, y, variant) => {
    const k = strength((full - gx) / cols, progress, shiny);
    ctx.fillStyle = pick(palette.base, 0.5 + (shade(gx, gy, 11) - 0.5) * k);
    box(x, y, cell);
    if (rand(gx, gy, 9) >= k) return; // flat cell
    ctx.fillStyle = pick(palette.square, 0.5 + (shade(gx + 40, gy, 13) - 0.5) * k);
    if (variant < 0.12) return box(x, y, cell);
    const flip = variant < 0.56 ? 0 : half;
    box(x + flip, y, half);
    box(x + half - flip, y + half, half);
  };

  // Shade of the remaining colour, then two small notches on a diagonal (or none).
  const remaining = (gx, gy, x, y, variant) => {
    ctx.fillStyle = pick(palette.remaining, shade(gx, gy, 21));
    box(x, y, cell);
    if (variant < 0.2) return; // plain cell
    ctx.fillStyle = pick(palette.notch, rand(gx, gy, 5));
    const flip = variant < 0.6 ? half : 0;
    box(x + flip, y, half / 2);
    box(x + half - flip, y + half, half / 2);
  };

  ctx.clearRect(0, 0, w, h);
  for (let gy = 0; gy < ROWS; gy++) {
    for (let gx = 0; gx < cols; gx++) {
      const on = gx < full || (gx === full && rand(gx, gy) < part);
      (on ? played : remaining)(gx, gy, gx * cell, gy * cell, rand(gx, gy, 3));
    }
  }
}

export const PixelProgress = {
  mounted() {
    this.canvas = this.el.querySelector("canvas");
    this.observer = new ResizeObserver(() => draw(this.el, this.canvas));
    this.observer.observe(this.canvas);
    draw(this.el, this.canvas);
  },
  updated() {
    draw(this.el, this.canvas);
  },
  destroyed() {
    this.observer?.disconnect();
  },
};
