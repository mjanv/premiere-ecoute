// Worn-paper texture over the session overlay, after priv/demos/poster-flipbook.html:
// specks (mostly tinted with the user's primary and secondary colours, read from the
// overlay root's data-primary/data-secondary), scratches, a lighter torn patch and a
// crease, drawn as opaque dark colours. The canvas is blended with
// `mix-blend-mode: lighten`, which keeps the lighter colour per channel: the texture
// lifts black areas, leaves lighter colours untouched, and overlaps never add up.
// A new random seed on every page load, kept for the life of the page so a resize
// redraws the same texture instead of making it jump.
import { onResize, rand, rgb } from "./overlay_canvas";

// Tuning knobs
const SPECKS = 700; // specks for a 1280x400 widget; scaled with the area
const SCRATCHES = 6; // scratches for a 1280x400 widget; scaled with the area
const PATCHES = 1; // torn lighter patches
const CREASES = 1; // faint horizontal fold lines
const STRENGTH = 1; // multiplies every level
const COLOUR = 0.7; // share of specks tinted with the user's primary or secondary colour
const COLOUR_BOOST = 3.5; // tinted specks are brighter, so their hue reads on black

function draw(canvas, seed) {
  const w = canvas.width;
  const h = canvas.height;
  const p = canvas.getContext("2d");
  const area = (w * h) / (1280 * 400);
  const unit = h / 400; // sizes follow the widget height
  const r = (a, b = 0, c = 0) => rand(a, b, c, seed);

  const root = canvas.closest("[data-overlay-root]");
  const tints = [rgb(root?.dataset.primary, "#ffffff"), rgb(root?.dataset.secondary, "#ffffff")];
  // Opaque colour: lighten blending needs the level, not a translucent white.
  const shade = (c, level) => `rgb(${c.map((v) => Math.round(Math.min(255, v * level * STRENGTH))).join(",")})`;
  const white = (level) => shade([255, 255, 255], level);
  // Specks: mostly tinted with the user's colours, some plain white.
  const speck = (level, k) => (k < COLOUR ? shade(tints[k < COLOUR / 2 ? 0 : 1], level * COLOUR_BOOST) : white(level));

  p.clearRect(0, 0, w, h);

  for (let i = 0; i < SPECKS * area; i++) {
    p.fillStyle = speck(0.02 + r(i, 1) * 0.09, r(i, 14));
    const s = Math.max(1, (1 + r(i, 2) * 2) * unit);
    p.fillRect(r(i, 3) * w, r(i, 4) * h, s, s);
  }

  p.lineWidth = Math.max(1, unit * 0.8);
  for (let i = 0; i < SCRATCHES * area; i++) {
    p.strokeStyle = white(0.03 + r(i, 5) * 0.06);
    const x = r(i, 6) * w;
    const y = r(i, 7) * h;
    const a = r(i, 8) * Math.PI;
    const l = (20 + r(i, 9) * 120) * unit;
    p.beginPath();
    p.moveTo(x, y);
    p.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l);
    p.stroke();
  }

  // Patch centres hug the corners and edges, where paper wears first.
  for (let k = 0; k < PATCHES; k++) {
    const cx = (r(k, 21) < 0.5 ? 0.04 + r(k, 22) * 0.15 : 0.81 + r(k, 22) * 0.15) * w;
    const cy = (r(k, 23) < 0.5 ? 0.08 + r(k, 24) * 0.2 : 0.72 + r(k, 24) * 0.2) * h;
    const radius = (60 + r(k, 25) * 90) * unit;
    const n = 90 + Math.floor(r(k, 26) * 170);
    for (let i = 0; i < n; i++) {
      const d = Math.pow(r(i * 1.37, k + 0.31, 5), 1.6) * radius;
      const a = r(i * 2.91, k + 0.77, 9) * Math.PI * 2;
      p.fillStyle = speck(0.012 + r(i * 3.3, 11, k) * 0.03, r(i, 15, k));
      const s = (3 + r(i * 4.7, 12, k) * 16) * unit;
      p.fillRect(cx + Math.cos(a) * d, cy + Math.sin(a) * d * 0.7, s, s * (0.4 + r(i, 13, k)));
    }
  }

  p.fillStyle = white(0.035);
  for (let k = 0; k < CREASES; k++) {
    p.fillRect(0, Math.round((0.25 + r(k, 31) * 0.5) * h), w, Math.max(1, Math.round(unit)));
  }
}

export const PaperTexture = {
  mounted() {
    const seed = Math.random() * 1000;
    this.observer = onResize(this.el, () => draw(this.el, seed));
  },
  destroyed() {
    this.observer?.disconnect();
  },
};
