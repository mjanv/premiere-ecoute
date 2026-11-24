// Dithered swipe for the session overlay score box, in the style
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
// Each swipe picks a variant at random (never the same twice in a row): a
// direction (left to right, right to left, top down, bottom up) and a texture
// (from clean slices to a shattered front). Across the sweep, "lanes" are the
// rows of a horizontal swipe and the columns of a vertical one.
// Canvas 2D on purpose: it looks the same with or without GPU acceleration.

// Tuning knobs
const DURATION = 1600; // ms, whole swipe
const ROWS = 44; // dot rows across the box height (cell size = height / ROWS)
const EDGE = 0.2; // width of each halftone ramp (leading and trailing), as a share of the box width
const CORE = 0.04; // width of the solid ink core, as a share of the box width
const SETTLE = 1000; // ms after mount during which swaps are not animated (initial load)
const DIRECTIONS = [
  { axis: "x", reverse: false },
  { axis: "x", reverse: true },
  { axis: "y", reverse: false },
  { axis: "y", reverse: true },
];
// slice: min and max width of a slice, in lanes; lag: max delay of a slice behind
// the leading one; scatter: how far stray dots spread ahead of and behind the band
// (both as a share of the sweep length).
const TEXTURES = [
  { slice: [1, 6], lag: 0.22, scatter: 0.18 }, // deconstructed
  { slice: [3, 10], lag: 0.1, scatter: 0.08 }, // clean blocks
  { slice: [1, 2], lag: 0.35, scatter: 0.25 }, // shattered
];

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

// Lanes grouped into slices of random width, each with its own lag.
function layout(lanes, { slice, lag }) {
  const lags = new Float32Array(lanes);
  for (let y = 0; y < lanes; ) {
    const width = slice[0] + Math.floor(Math.random() * (slice[1] - slice[0] + 1));
    const l = Math.random() * lag;
    for (let i = y; i < Math.min(lanes, y + width); i++) lags[i] = l;
    y += width;
  }
  return lags;
}

let last = -1;
function variant() {
  const count = DIRECTIONS.length * TEXTURES.length;
  let i;
  do i = Math.floor(Math.random() * count);
  while (i === last && count > 1);
  last = i;
  return { ...DIRECTIONS[i % DIRECTIONS.length], ...TEXTURES[Math.floor(i / DIRECTIONS.length)] };
}

// Clip polygon keeping the part of the ghost the band has not reached yet. cuts
// holds, per lane, how far along the sweep the cut is (0..100).
function clip({ axis, reverse }, cuts, edges) {
  const points = [];
  cuts.forEach((c, i) => {
    const cut = reverse ? 100 - c : c;
    const [a, b] = [edges[i], edges[i + 1]];
    if (axis === "x") points.push(`${cut}% ${a}%`, `${cut}% ${b}%`);
    else points.push(`${a}% ${cut}%`, `${b}% ${cut}%`);
  });
  const far = reverse ? 0 : 100;
  const open = axis === "x" ? [`${far}% 0%`, `${far}% 100%`] : [`0% ${far}%`, `100% ${far}%`];
  return `polygon(${open[0]}, ${points.join(", ")}, ${open[1]})`;
}

function draw(swap, now) {
  const { canvas, ctx, start, ink, ghost, seed, variant: v } = swap;
  const t = clamp((now - start) / DURATION);
  const w = canvas.width;
  const h = canvas.height;
  const cell = Math.max(2, Math.round(h / ROWS));
  const cols = Math.ceil(w / cell);
  const rows = Math.ceil(h / cell);
  const horizontal = v.axis === "x";
  const lanes = horizontal ? rows : cols;
  const length = horizontal ? cols : rows;
  swap.lags ||= layout(lanes, v);
  const lags = swap.lags;
  // Leading edge, in sweep lengths: from the starting border until the most
  // delayed slice and its stray dots have left the box.
  const front = easeInOut(t) * (1 + 2 * EDGE + CORE + v.lag + v.scatter);

  // The ghost is cut along the middle of each slice's core.
  if (ghost) {
    const span = horizontal ? h : w;
    const edges = Array.from({ length: lanes + 1 }, (_, i) => Math.min(100, ((i * cell) / span) * 100));
    const cuts = Array.from(lags, (lag) => clamp(front - lag - EDGE - CORE / 2) * 100);
    ghost.style.clipPath = clip(v, cuts, edges);
  }

  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = ink;
  for (let lane = 0; lane < lanes; lane++) {
    const head = front - lags[lane];
    for (let i = 0; i < length; i++) {
      const pos = v.reverse ? length - 1 - i : i;
      const d = head - (i + 0.5) / length;
      if (d < -v.scatter / 2 || d > 2 * EDGE + CORE + v.scatter / 2) continue;
      const x = horizontal ? pos : lane;
      const y = horizontal ? lane : pos;
      // The core stays solid (it hides the ghost cut); elsewhere dots wander.
      const solid = d >= EDGE && d < EDGE + CORE;
      const k = solid ? 1 : density(d + (hash(x, y, seed) - 0.5) * v.scatter);
      if (k <= 0 || (!solid && k <= BAYER[y & 7][x & 7])) continue;
      const x0 = x * cell;
      const y0 = y * cell;
      const side = dot(k);
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
      variant: variant(),
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
