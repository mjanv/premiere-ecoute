import { PALETTES, backdrop, clamp, cover, span, stepped } from "../kit";

// Cover wall: every cover of the year lands one after the other, each one first a flat colour,
// then a coarse mosaic, then itself. A wall taller than the screen scrolls up in steps.

export const duration = 12;

const STEPS = [1, 2, 4, 8];

export function draw(s, card, t, { labels, covers }) {
  const pal = PALETTES.plum;
  const list = card.data.covers;
  const count = list.length;
  const top = 22;
  const bottom = s.h - 33;
  // The fewest columns whose rows fit the screen: covers as large as they can be. Past five columns the wall scrolls.
  const fits = (n) => Math.ceil(count / n) * (Math.floor((s.w - (n + 1)) / n) + 1) <= bottom - top;
  const cols = [2, 3, 4].find(fits) || 5;
  const tile = Math.floor((s.w - (cols + 1)) / cols);
  const left = Math.floor((s.w - cols * (tile + 1) + 1) / 2);
  const rows = Math.ceil(count / cols);
  const each = Math.min(0.24, 5 / count);
  const landed = 0.6 + count * each + 0.6;
  const overflow = Math.max(0, rows * (tile + 1) - (bottom - top));
  const scroll = Math.round(overflow * stepped(span(t, landed, duration - 1.2), Math.max(1, Math.ceil(overflow / 4))));

  backdrop(s, pal);

  list.forEach((entry, k) => {
    const x = left + (k % cols) * (tile + 1);
    const y = top + Math.floor(k / cols) * (tile + 1) - scroll;
    if (y > bottom || y + tile < top) return;

    const age = t - 0.6 - k * each;
    if (age < 0) return s.dither(x, y, tile, tile, pal.bg, pal.dim, 0.25);

    const step = Math.floor(age / 0.11);
    cover(s, covers, entry.cover_url, x, y, tile, { res: step < STEPS.length ? STEPS[step] : tile, pal, tick: k });
  });

  // The margins of the poster hide the wall as it scrolls. Under it: how many, and what they are.
  s.front.rect(0, 0, s.w, top, pal.bg);
  s.front.rect(0, bottom, s.w, s.h - bottom, pal.bg);

  const landing = clamp(Math.floor((t - 0.6) / each) + 1, 0, count);
  const width = s.front.type(String(landing), 6, bottom + 4, { size: 14, weight: 700, color: pal.hot });
  s.front.type(labels.albums(landing), 6 + width + 2.5, bottom + 9.6, { size: 7, color: pal.hot });
  s.front.type(labels.every_cover, 120, bottom + 11.4, { size: 3.4, mono: true, upper: true, spacing: 0.2, color: pal.hot, alpha: 0.66, align: "right", max: 70 });
}
