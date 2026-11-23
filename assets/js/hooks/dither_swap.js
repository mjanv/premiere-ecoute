// Dithered left-to-right swipe for the session overlay score box, in the style
// of priv/demos/dither-cards.html: square dots from an 8x8 Bayer threshold whose
// size grows with density.
//
// When the box's data-key changes (vote state or shown content), the old content
// is kept as a ghost layer and a halftone band crosses the box from left to
// right: sparse dots grow into a solid core, which then thins out again. The
// ghost is clipped at the middle of the core, so the old content is swapped for
// the new one under solid ink. The ink is the new background when it changes,
// the new text colour when it does not (a black to black swap shows green dots).
// The band is deconstructed: rows are grouped into slices of random height that
// each run with their own lag (a jagged, glitched front, also used to cut the
// ghost), and dots scatter ahead of and behind the band. A new random layout is
// drawn for every swipe.
// Canvas 2D on purpose: it looks the same with or without GPU acceleration.

// Tuning knobs
const DURATION = 1100; // ms, whole swipe
const ROWS = 44; // dot rows across the box height (cell size = height / ROWS)
const EDGE = 0.2; // width of each halftone ramp (leading and trailing), as a share of the box width
const CORE = 0.04; // width of the solid ink core, as a share of the box width
const SETTLE = 1000; // ms after mount during which swaps are not animated (initial load)
const SLICE = [1, 6]; // min and max height of a slice, in dot rows
const LAG = 0.22; // max delay of a slice behind the leading one, as a share of the box width
const SCATTER = 0.18; // how far stray dots spread ahead of and behind the band, as a share of the box width

const BAYER = (() => {
  const b = (n) => {
    if (n === 1) return [[0]];
    const m = b(n / 2);
    const h = n / 2;
    const out = Array.from({ length: n }, () => Array(n).fill(0));
    for (let y = 0; y < h; y++)
      for (let x = 0; x < h; x++) {
        const v = 4 * m[y][x];
        out[y][x] = v;
        out[y][x + h] = v + 2;
        out[y + h][x] = v + 3;
        out[y + h][x + h] = v + 1;
      }
    return out;
  };
  return b(8).map((row) => row.map((v) => ((v + 0.5) / 64) * 0.94 + 0.03));
})();

const clamp = (v) => (v < 0 ? 0 : v > 1 ? 1 : v);
const smooth = (a, b, v) => {
  const t = clamp((v - a) / (b - a));
  return t * t * (3 - 2 * t);
};
const easeInOut = (t) => -(Math.cos(Math.PI * t) - 1) / 2;

// Dot side for a density, in cells: sparse areas keep small separate squares,
// dense areas close up.
const dot = (v) => Math.min(1, 0.4 + 0.75 * smooth(0.2, 0.85, v));

// Ink density of a column at distance d behind the leading edge of the band.
function density(d) {
  if (d <= 0) return 0;
  if (d < EDGE) return d / EDGE;
  if (d < EDGE + CORE) return 1;
  return clamp(1 - (d - EDGE - CORE) / EDGE);
}

// Deterministic 0..1 noise per cell and swipe.
function hash(x, y, seed) {
  let n = Math.imul(x, 374761393) + Math.imul(y, 668265263) + Math.imul(seed, 2246822519);
  n = Math.imul(n ^ (n >>> 13), 1274126177);
  return ((n ^ (n >>> 16)) >>> 0) / 4294967296;
}

// Rows grouped into slices of random height, each with its own lag.
function layout(rows) {
  const lags = new Float32Array(rows);
  for (let y = 0; y < rows; ) {
    const height = SLICE[0] + Math.floor(Math.random() * (SLICE[1] - SLICE[0] + 1));
    const lag = Math.random() * LAG;
    for (let i = y; i < Math.min(rows, y + height); i++) lags[i] = lag;
    y += height;
  }
  return lags;
}

function draw(swap, now) {
  const { canvas, ctx, start, ink, ghost, seed } = swap;
  const t = clamp((now - start) / DURATION);
  const w = canvas.width;
  const h = canvas.height;
  const cell = Math.max(2, Math.round(h / ROWS));
  const cols = Math.ceil(w / cell);
  const rows = Math.ceil(h / cell);
  swap.lags ||= layout(rows);
  const lags = swap.lags;
  // Leading edge, in box widths: from the left border until the most delayed
  // slice and its stray dots have left the box.
  const front = easeInOut(t) * (1 + 2 * EDGE + CORE + LAG + SCATTER);

  // The ghost is cut along the middle of each slice's core.
  if (ghost) {
    const points = [];
    for (let y = 0; y < rows; y++) {
      const cut = clamp(front - lags[y] - EDGE - CORE / 2) * 100;
      const top = Math.min(100, ((y * cell) / h) * 100);
      const bottom = Math.min(100, (((y + 1) * cell) / h) * 100);
      points.push(`${cut}% ${top}%`, `${cut}% ${bottom}%`);
    }
    ghost.style.clipPath = `polygon(100% 0%, ${points.join(", ")}, 100% 100%)`;
  }

  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = ink;
  for (let y = 0; y < rows; y++) {
    const head = front - lags[y];
    const y0 = y * cell;
    for (let x = 0; x < cols; x++) {
      const d = head - (x + 0.5) / cols;
      if (d < -SCATTER / 2 || d > 2 * EDGE + CORE + SCATTER / 2) continue;
      // The core stays solid (it hides the ghost cut); elsewhere dots wander.
      const solid = d >= EDGE && d < EDGE + CORE;
      const v = solid ? 1 : density(d + (hash(x, y, seed) - 0.5) * SCATTER);
      if (v <= 0 || (!solid && v <= BAYER[y & 7][x & 7])) continue;
      const x0 = x * cell;
      const side = dot(v);
      if (side >= 1) {
        ctx.fillRect(x0, y0, Math.min(w, x0 + cell) - x0, Math.min(h, y0 + cell) - y0);
      } else {
        const px = Math.max(1, Math.round(cell * side));
        const inset = Math.floor((cell - px) / 2);
        ctx.fillRect(x0 + inset, y0 + inset, px, px);
      }
    }
  }
  return t;
}

function colours(root) {
  const style = getComputedStyle(root);
  return { bg: style.backgroundColor, fg: style.color };
}

// Copy of the current content (without the swap layer), with ids and hooks stripped.
function snapshot(el, layer, bg, fg) {
  const ghost = document.createElement("div");
  ghost.style.cssText = `position:absolute;inset:0;display:flex;align-items:center;justify-content:center;background:${bg};color:${fg};`;
  for (const child of el.children) {
    if (child === layer) continue;
    const copy = child.cloneNode(true);
    for (const node of [copy, ...copy.querySelectorAll("[id],[phx-hook]")]) {
      node.removeAttribute?.("id");
      node.removeAttribute?.("phx-hook");
    }
    ghost.appendChild(copy);
  }
  return ghost;
}

export const DitherSwap = {
  mounted() {
    this.root = this.el.closest("[data-overlay-root]") || this.el;
    this.layer = this.el.querySelector("[phx-update=ignore]");
    this.key = this.el.dataset.key;
    this.colours = colours(this.root);
    this.mountedAt = performance.now();
  },

  beforeUpdate() {
    // The element still holds the old content and key here.
    this.pending = {
      key: this.key,
      colours: this.colours,
      ghost: snapshot(this.el, this.layer, this.colours.bg, this.colours.fg),
    };
  },

  updated() {
    const pending = this.pending;
    this.pending = null;
    this.key = this.el.dataset.key;
    this.colours = colours(this.root);
    if (!pending || pending.key === this.key) return;
    if (performance.now() - this.mountedAt < SETTLE) return;
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    this.play(pending);
  },

  play({ colours: old, ghost }) {
    this.stop();
    const { bg, fg } = this.colours;
    const canvas = document.createElement("canvas");
    canvas.style.cssText = "position:absolute;inset:0;width:100%;height:100%;display:block;";
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.max(2, Math.round(this.layer.clientWidth * ratio));
    canvas.height = Math.max(2, Math.round(this.layer.clientHeight * ratio));
    this.layer.append(ghost, canvas);

    const swap = {
      canvas,
      ctx: canvas.getContext("2d"),
      start: performance.now(),
      ink: old.bg === bg ? fg : bg,
      ghost,
      seed: Math.floor(Math.random() * 1e9),
      lags: null,
    };
    this.swap = swap;

    const frame = (now) => {
      if (this.swap !== swap) return;
      if (draw(swap, now) < 1) this.raf = requestAnimationFrame(frame);
      else this.stop();
    };
    frame(swap.start);
  },

  stop() {
    if (this.raf) cancelAnimationFrame(this.raf);
    this.raf = null;
    this.swap = null;
    this.layer?.replaceChildren();
  },

  destroyed() {
    this.stop();
  },
};
