// Shared helpers for the session overlay canvas hooks (textures, progress bar,
// liquid field, film grain).

// Sizes a canvas to its CSS box at the device pixel ratio (capped at 2).
// Returns the ratio used and whether the backing store changed.
export function fitCanvas(canvas) {
  const ratio = Math.min(window.devicePixelRatio || 1, 2);
  const w = Math.max(2, Math.round(canvas.clientWidth * ratio));
  const h = Math.max(2, Math.round(canvas.clientHeight * ratio));
  const changed = w !== canvas.width || h !== canvas.height;
  if (changed) {
    canvas.width = w;
    canvas.height = h;
  }
  return { ratio, changed };
}

// Calls draw(ratio) now and whenever the canvas size changes. Returns the observer
// (disconnect it in the hook's destroyed()).
export function onResize(canvas, draw) {
  const resize = () => {
    const { ratio, changed } = fitCanvas(canvas);
    if (changed) draw(ratio);
  };
  const observer = new ResizeObserver(resize);
  observer.observe(canvas);
  resize();
  return observer;
}

// Deterministic pseudo-random number in 0..1 for the given coordinates and seed.
export function rand(a, b = 0, c = 0, seed = 0) {
  const s = Math.sin(a * 127.1 + b * 311.7 + c * 74.7 + seed) * 43758.5453;
  return s - Math.floor(s);
}

let parser;

// Any CSS colour to [r, g, b] in 0..255, through the canvas colour parser.
// Unparseable or missing colours give `fallback`.
export function rgb(colour, fallback = "#000000") {
  parser ||= document.createElement("canvas").getContext("2d");
  parser.fillStyle = fallback;
  parser.fillStyle = colour || fallback;
  const value = parser.fillStyle;
  if (value.startsWith("#")) return [1, 3, 5].map((i) => parseInt(value.slice(i, i + 2), 16));
  return value.match(/\d+/g).slice(0, 3).map(Number);
}

export const clamp01 = (v) => Math.min(1, Math.max(0, v));
