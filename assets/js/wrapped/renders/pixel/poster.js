// The full-resolution side of the pixel render: what a printed poster has and a pixel grid cannot give.
// Gradient panels, soft glows, real type, and a sheet of worn paper. A unit is one pixel of the grid.

const SANS = '"Bricolage Grotesque", "Helvetica Neue", Arial, sans-serif';
const MONO = 'ui-monospace, "SF Mono", Menlo, Consolas, "DejaVu Sans Mono", monospace';
const WIDTH = 126;

export const css = (color, alpha = 1) => `rgba(${Math.round(color[0])},${Math.round(color[1])},${Math.round(color[2])},${alpha})`;

// Loads the weights the posters are set in: a canvas does not fetch a font on its own
export const fonts = () => Promise.all([500, 700].map((weight) => document.fonts.load(`${weight} 16px ${SANS}`, "A"))).catch(() => {});

const rand = (a, b = 0, c = 0) => {
  const s = Math.sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453;
  return s - Math.floor(s);
};

export class Layer {
  constructor(ctx) {
    this.ctx = ctx;
    this.w = WIDTH;
    this.h = 0;
  }

  rect(x, y, w, h, color, alpha = 1) {
    this.ctx.fillStyle = css(color, alpha);
    this.ctx.fillRect(x, y, w, h);
  }

  fill(color) {
    this.rect(0, 0, this.w, this.h, color);
  }

  // A panel going from the dark of a palette to its light, top to bottom
  panel(x, y, w, h, pal, alpha = 1) {
    const gradient = this.ctx.createLinearGradient(0, y, 0, y + h);
    gradient.addColorStop(0, css(pal.bg, alpha));
    gradient.addColorStop(0.2, css(pal.a, alpha));
    gradient.addColorStop(0.46, css(pal.b, alpha));
    gradient.addColorStop(0.8, css(pal.hot, alpha));
    gradient.addColorStop(1, css(pal.hot, alpha));
    this.ctx.fillStyle = gradient;
    this.ctx.fillRect(x, y, w, h);
  }

  // A fade between two alphas of one colour, top to bottom
  fade(x, y, w, h, color, from, to) {
    const gradient = this.ctx.createLinearGradient(0, y, 0, y + h);
    gradient.addColorStop(0, css(color, from));
    gradient.addColorStop(1, css(color, to));
    this.ctx.fillStyle = gradient;
    this.ctx.fillRect(x, y, w, h);
  }

  // A tilted, flattened halo: `colors` from its heart outwards, the last one fading to nothing
  glow(cx, cy, radius, colors, { angle = -0.62, squash = 0.44, alpha = 1 } = {}) {
    const c = this.ctx;
    c.save();
    c.translate(cx, cy);
    c.rotate(angle);
    c.scale(1, squash);
    const gradient = c.createRadialGradient(0, 0, 0, 0, 0, radius);
    const last = colors.length - 1;
    colors.forEach((color, index) => gradient.addColorStop((index / (last + 1)) * 0.82, css(color, alpha)));
    gradient.addColorStop(0.82, css(colors[last], alpha * 0.45));
    gradient.addColorStop(1, css(colors[last], 0));
    c.fillStyle = gradient;
    c.beginPath();
    c.arc(0, 0, radius, 0, Math.PI * 2);
    c.fill();
    c.restore();
  }

  font({ size = 6, mono = false, weight = 500, spacing = 0 } = {}) {
    this.ctx.font = `${weight} ${size}px ${mono ? MONO : SANS}`;
    if ("letterSpacing" in this.ctx) this.ctx.letterSpacing = `${spacing}px`;
  }

  measure(text, style) {
    this.font(style);
    return this.ctx.measureText(text).width;
  }

  // One line of type, its top at y. `align` places it around x, `max` squeezes it. Returns its width.
  type(text, x, y, style = {}) {
    const { size = 6, color = [255, 255, 255], alpha = 1, align = "left", max, upper = false } = style;
    const c = this.ctx;
    const line = upper ? String(text ?? "").toUpperCase() : String(text ?? "");

    this.font(style);
    c.textAlign = align;
    c.textBaseline = "alphabetic";
    c.fillStyle = css(color, alpha);
    c.fillText(line, x, y + size * 0.8, max);
    return Math.min(c.measureText(line).width, max || Infinity);
  }

  // Cuts a text into lines no wider than `width`, with an ellipsis past `lines` lines
  wrap(text, width, lines, style) {
    const words = String(text ?? "").split(/\s+/).filter(Boolean);
    const rows = [];
    let row = "";

    this.font(style);
    for (const word of words) {
      const longer = row ? `${row} ${word}` : word;
      if (!row || this.ctx.measureText(longer).width <= width) row = longer;
      else {
        rows.push(row);
        row = word;
      }
    }
    if (row) rows.push(row);
    if (rows.length <= lines) return rows;

    let last = rows[lines - 1];
    while (last.length > 1 && this.ctx.measureText(`${last}…`).width > width) last = last.slice(0, -1);
    return [...rows.slice(0, lines - 1), `${last.trimEnd()}…`];
  }

  // A paragraph. `shown` types it: only that many characters are drawn, in place. Returns the y under it.
  block(text, x, y, width, style = {}) {
    const { size = 6, leading = 1.08, lines = 2, shown = Infinity, upper = false } = style;
    const rows = this.wrap(upper ? String(text ?? "").toUpperCase() : text, width, lines, style);
    let left = shown;

    rows.forEach((row, index) => {
      if (left > 0) this.type(row.slice(0, left), x, y + index * size * leading, { ...style, upper: false, max: width });
      left -= row.length + 1;
    });
    return y + rows.length * size * leading;
  }

  // A line of type turned a quarter, reading upwards from (x, y)
  vertical(text, x, y, style = {}) {
    const c = this.ctx;
    c.save();
    c.translate(x, y);
    c.rotate(-Math.PI / 2);
    this.type(text, 0, 0, style);
    c.restore();
  }
}

// Worn paper, drawn once per size: speckles, scratches, two creases and torn corners.
// Light marks for a dark poster, ink marks for a light one.
export function paper(w, h, unit, light) {
  const canvas = document.createElement("canvas");
  canvas.width = w * unit;
  canvas.height = h * unit;
  const p = canvas.getContext("2d");
  const tone = light ? "16,16,20" : "255,255,255";
  p.scale(unit, unit);

  for (let i = 0; i < w * h * 0.26; i++) {
    const size = 0.16 + rand(i, 2) * 0.34;
    p.fillStyle = `rgba(${tone},${0.02 + rand(i, 1) * 0.09})`;
    p.fillRect(rand(i, 3) * w, rand(i, 4) * h, size, size);
  }
  for (let i = 0; i < 50; i++) {
    const x = rand(i, 6) * w;
    const y = rand(i, 7) * h;
    const angle = rand(i, 8) * Math.PI;
    const length = 3 + rand(i, 9) * 19;
    p.strokeStyle = `rgba(${tone},${0.03 + rand(i, 5) * 0.06})`;
    p.lineWidth = 0.16;
    p.beginPath();
    p.moveTo(x, y);
    p.lineTo(x + Math.cos(angle) * length, y + Math.sin(angle) * length);
    p.stroke();
  }
  for (const [cx, cy, count] of [[11, 11, 240], [112, 9, 180], [19, h - 11, 90]]) {
    for (let i = 0; i < count; i++) {
      const radius = Math.pow(rand(i * 1.37, cx + 0.31, 5), 1.6) * 21;
      const angle = rand(i * 2.91, cy + 0.77, 9) * Math.PI * 2;
      const size = 0.3 + rand(i * 4.7, 12, cy) * 1.1;
      p.fillStyle = `rgba(${tone},${0.015 + rand(i * 3.3, 11, cx) * 0.045})`;
      p.fillRect(cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius * 0.7, size, size * (0.4 + rand(i, 13)));
    }
  }
  for (const y of [h / 3, (h * 2) / 3]) {
    p.fillStyle = `rgba(${tone},0.04)`;
    p.fillRect(0, y, w, 0.16);
  }
  return canvas;
}
