import { hex, mix, bayer } from "./screen";
import { clean, glyph } from "./font";

// Drawing kit of the pixel render: palettes, timing helpers and the pieces the cards are built from.

// Five colours each: background, a dim tone, two colours and a hot accent.
// The first three come from the folding ribbons of light, mint from the poster with the squashed marks.
const palette = (bg, dim, a, b, hot) => ({ bg: hex(bg), dim: hex(dim), a: hex(a), b: hex(b), hot: hex(hot) });

export const PALETTES = {
  plum: palette("#0d060c", "#3a1420", "#8a2f3c", "#b08cf0", "#fff0fb"),
  sea: palette("#04090d", "#0a2a33", "#0f5a6a", "#66e0d0", "#f0fffb"),
  ember: palette("#0d0704", "#3a1408", "#8a2a10", "#ffa552", "#fff6e6"),
  mint: palette("#0e1a17", "#18504a", "#19b7a4", "#c79ad6", "#ff93d2"),
};

// --- Time ------------------------------------------------------------------------

export const clamp = (value, min = 0, max = 1) => Math.min(max, Math.max(min, value));

// Progress from 0 to 1 between two moments
export const span = (t, from, to) => clamp((t - from) / (to - from));

// The same progress in `count` hard steps, like frames of a flipbook
export const stepped = (progress, count) => Math.floor(progress * count) / count;

// How many beats of `every` seconds have passed since `from`
export const beats = (t, from, every) => (t < from ? -1 : Math.floor((t - from) / every));

// Deterministic noise, so that a card looks the same every time it is played
export const hash = (a, b = 0, c = 0) => {
  const s = Math.sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453;
  return s - Math.floor(s);
};

const smooth = (x, seed) => {
  const i = Math.floor(x);
  const f = x - i;
  const k = f * f * (3 - 2 * f);
  return hash(i, seed) * (1 - k) + hash(i + 1, seed) * k;
};

// --- Pieces ----------------------------------------------------------------------

// Fills the poster with the ground colour of a palette, and tells the screen which paper and ink go with it
export function backdrop(s, pal) {
  s.back.fill(pal.bg);
  s.light = pal.bg[0] + pal.bg[1] + pal.bg[2] > 380;
  s.ink = pal.hot;
}

// How many characters of a text are typed so far
export const chars = (t, from, speed = 28) => Math.max(0, Math.floor((t - from) * speed));

// A softer ink, for second lines
export const soft = (pal, k = 0.62) => mix(pal.bg, pal.hot, k);

// The heading of a card, set large and typed under the controls. Returns the y where the card can start.
export function heading(s, text, t, pal) {
  const y = s.front.block(text, 6, 25, 112, { size: 12, lines: 3, leading: 1.02, color: pal.hot, shown: chars(t, 0.3) });
  return Math.round(y) + 7 + lift(s);
}

// What every poster carries in its margins: the mark at the top, the edition and the page at the bottom
export function chrome(s, year, page, mark = true) {
  const f = s.front;
  const ink = s.ink;

  if (mark) brand(s, 6, 10.5, 4.8);
  if (!page) return;
  const style = { size: 3.3, mono: true, color: s.foot || ink, alpha: 0.66, spacing: 0.2 };
  f.type(`WRAPPED ${year}`, 6, s.h - 9, style);
  f.type(`${String(page.index + 1).padStart(2, "0")} / ${String(page.count).padStart(2, "0")}`, 120, s.h - 9, { ...style, align: "right" });
}

// The mark of Premiere Ecoute, a record seen from above, and its name. `suffix` follows the name. Returns its width.
export function brand(s, x, y, size, suffix = "") {
  const f = s.front;
  const ink = s.ink;
  const radius = size * 0.5;
  const text = `Premiere Ecoute${suffix}`;
  const style = { size, weight: 700, color: ink };

  // The record sits on the middle of the capitals, as measured: the font decides, not a guess
  f.font(style);
  const capitals = f.ctx.measureText("PE").actualBoundingBoxAscent || size * 0.7;
  const middle = y + size * 0.8 - capitals / 2;

  f.ctx.fillStyle = `rgb(${ink.map(Math.round).join(",")})`;
  f.ctx.beginPath();
  f.ctx.arc(x + radius, middle, radius, 0, Math.PI * 2);
  f.ctx.arc(x + radius, middle, radius / 3, 0, Math.PI * 2, true);
  f.ctx.fill();
  f.type(text, x + size * 1.38, y, style);
  return size * 1.38 + f.measure(text, style);
}

// On a screen taller than 9:16, cards start a little lower so that they do not hang at the top
export const lift = (s) => Math.max(0, Math.floor((s.h - 224) * 0.35));

// Chunky letters pushed out of the screen: a stack of offset copies behind a bright face
export function chunky(s, text, x, y, scale, { depth = 4, face, side, edge, align = "left" } = {}) {
  const line = clean(text);
  const width = (line.length * 6 - 1) * scale;
  const left = Math.round(align === "center" ? x - width / 2 : align === "right" ? x - width : x);
  const cells = [];

  [...line].forEach((char, index) => {
    const rows = glyph(char);
    if (!rows) return;
    for (let j = 0; j < 7; j++) {
      for (let i = 0; i < 5; i++) {
        // The third value tells whether the cell is the top of a stroke, where the light catches
        if (rows[j][i] === "#") cells.push([left + (index * 6 + i) * scale, y + j * scale, j === 0 || rows[j - 1][i] !== "#"]);
      }
    }
  });

  for (let k = depth; k >= 1; k--) {
    const color = k % 2 ? side : mix(side, [0, 0, 0], 0.35);
    for (const [cx, cy] of cells) s.rect(cx + k, cy + k, scale, scale, color);
  }
  for (const [cx, cy, top] of cells) {
    s.rect(cx, cy, scale, scale, face);
    if (edge && top && scale > 2) s.rect(cx, cy, scale, 1, edge);
  }
  return width;
}

// A staggered grid of dots with a moving skyline: dots under it are lit, with a white crest,
// and faint beams rise above its tallest columns. `level` is the average height, from 0 to 1.
export function skyline(s, x, y, w, h, t, level, pal, seed = 0) {
  const tick = Math.floor(t * 5);

  for (let i = 0; i < w; i++) {
    const u = i / w;
    const column = Math.floor(i / 2);
    const wave = smooth(u * 5 + t * 0.12, seed) - 0.5 + (smooth(u * 13 - t * 0.2, seed + 3) - 0.5) * 0.6;
    const spike = Math.pow(hash(column, seed + 7), 6) * 0.5;
    const top = clamp(level + wave * 0.5 * Math.min(1, level * 3) + spike * level, 0, 1) * h;

    for (let j = 0; j < h; j++) {
      const px = x + i;
      const py = y + h - 1 - j;
      const dot = (px + py) % 2 === 0;

      if (j < top) {
        if (!dot) {
          s.px(px, py, mix(pal.bg, pal.a, 0.35));
          continue;
        }
        const depth = top - j;
        let color = mix(pal.a, pal.b, clamp(j / (h * 0.6)));
        if (depth < 3) color = pal.hot;
        else if (hash(px, py, tick) > 0.93) color = pal.hot;
        s.px(px, py, color);
      } else if (dot) {
        const beam = top > h * 0.45 ? Math.exp(-(j - top) / (h * 0.35)) * hash(column, seed + 11) : 0;
        s.px(px, py, bayer(px >> 1, py >> 1) < beam ? pal.a : mix(pal.bg, pal.dim, 0.5));
      }
    }
  }
}

// A checkerboard with bigger squares scattered over it, reshuffled on every tick
export function checker(s, x, y, w, h, cell, pal, tick, seed = 0) {
  for (let j = 0; j < h; j++) {
    for (let i = 0; i < w; i++) {
      const cx = Math.floor(i / cell);
      const cy = Math.floor(j / cell);
      const big = hash(Math.floor(cx / 2) + seed * 13, Math.floor(cy / 2), tick);
      let color = (cx + cy) % 2 ? pal.b : pal.bg;
      if (big < 0.12) color = pal.a;
      else if (big < 0.22) color = pal.hot;
      s.px(x + i, y + j, color);
    }
  }
}

// A pixelated six-armed burst, turning in small jumps
export function burst(s, cx, cy, radius, t, pal) {
  const turn = Math.floor(t * 3) * 0.09;

  for (let j = -radius; j <= radius; j++) {
    for (let i = -radius; i <= radius; i++) {
      const r = Math.hypot(i, j) / radius;
      if (r > 1 || r < 0.12) continue;
      const angle = Math.atan2(j, i) + turn;
      const arm = Math.abs(Math.cos(angle * 3));
      if (!(arm > 0.25 && r < 0.4 + 0.6 * arm)) continue;
      const shade = j / radius / 2 + 0.5 + 0.2 * Math.sin(angle * 3);
      s.px(cx + i, cy + j, bayer(cx + i, cy + j) < shade ? pal.b : pal.a);
    }
  }
}

// A cover drawn as a mosaic of `res` cells per side. `amount` (1 to 0) takes it apart and puts it back together:
// in "slices" the rows slide sideways, in "tiles" a 4×4 grid of tiles is scattered.
export function cover(s, covers, url, x, y, size, { res = 64, mode = "slices", amount = 0, pal, tick = 0 } = {}) {
  const level = covers.level(url, Math.min(res, size));
  x = Math.round(x);
  y = Math.round(y);

  for (let j = 0; j < size; j++) {
    for (let i = 0; i < size; i++) {
      let dx = 0;
      let dy = 0;
      if (amount > 0) {
        if (mode === "slices") {
          const band = Math.floor((j / size) * 12);
          dx = Math.round((hash(band, 3) - 0.5) * 2 * amount * size * 0.9);
        } else {
          const tile = Math.floor((i / size) * 4) + Math.floor((j / size) * 4) * 4;
          dx = Math.round((hash(tile, 5) - 0.5) * 2 * amount * size * 0.8);
          dy = Math.round((hash(tile, 9) - 0.5) * 2 * amount * size * 0.8);
        }
      }

      let color;
      if (level) {
        const cx = Math.floor((i / size) * level.res);
        const cy = Math.floor((j / size) * level.res);
        const o = (cy * level.res + cx) * 4;
        color = [level.data[o], level.data[o + 1], level.data[o + 2]];
      } else {
        // Not loaded yet: a dithered placeholder that shimmers
        color = bayer(i + tick, j) < 0.5 ? pal.dim : pal.a;
      }
      s.px(x + i + dx, y + j + dy, color);
    }
  }
}

// A record seen from above: dark grooves, a glint, and the cover as its label, turning in small jumps
export function disc(s, covers, url, cx, cy, radius, angle, { hole = 1.5, pal, label = 0.42 } = {}) {
  const level = covers.level(url, 32);
  const inner = radius * label;
  const cos = Math.cos(-angle);
  const sin = Math.sin(-angle);

  for (let j = -radius; j <= radius; j++) {
    for (let i = -radius; i <= radius; i++) {
      const d = Math.hypot(i, j);
      if (d > radius + 0.3) continue;
      const px = Math.round(cx + i);
      const py = Math.round(cy + j);

      if (d < hole) {
        s.px(px, py, pal.bg);
      } else if (d < inner) {
        const u = (i * cos - j * sin) / inner / 2 + 0.5;
        const v = (i * sin + j * cos) / inner / 2 + 0.5;
        if (level) {
          const o = (clamp(Math.floor(v * level.res), 0, level.res - 1) * level.res + clamp(Math.floor(u * level.res), 0, level.res - 1)) * 4;
          s.px(px, py, [level.data[o], level.data[o + 1], level.data[o + 2]]);
        } else {
          s.px(px, py, bayer(px, py) < 0.5 ? pal.a : pal.b);
        }
      } else {
        const theta = Math.atan2(j, i);
        const glint = Math.pow(Math.abs(Math.cos(theta - 0.9)), 24);
        const groove = Math.floor(d) % 2 ? [22, 22, 26] : [38, 38, 44];
        s.px(px, py, bayer(px, py) < glint * 0.9 ? [150, 150, 160] : d > radius - 1 ? [10, 10, 12] : groove);
      }
    }
  }
}

// A number with one decimal, as scores are shown
export const score = (value) => Number(value).toFixed(1);
