import { PALETTES, backdrop, burst, chars, chunky, cover, heading, lift, score } from "../kit";

// Top album: the slow one. The label is typed on an empty poster, then the cover sharpens from a
// single colour to itself, one step at a time. A flash, a panel of light rises behind it, and the score lands.

export const duration = 13;

const STEPS = [1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64];
const STEP_S = 0.4;
const FROM_S = 1.8;
const DONE_S = FROM_S + STEPS.length * STEP_S;

export function draw(s, card, t, { labels, covers }) {
  const pal = PALETTES.ember;
  const album = card.data.album;
  // Edge to edge where the screen is tall enough
  const size = Math.min(s.w, s.h - 124);
  const left = Math.round((s.w - size) / 2);
  const done = t >= DONE_S + 0.12;

  backdrop(s, pal);
  // One frame of light when the cover is whole
  if (t >= DONE_S && !done) s.back.fill(pal.hot);
  const top = heading(s, labels.album_of_year, t, pal) + 2 - lift(s);

  if (done) {
    s.back.panel(0, top + size * 0.5, s.w, s.h, pal);
    s.foot = pal.bg;
    burst(s, left + size / 2, top + size / 2, Math.floor(size * 0.72), t, { a: pal.a, b: pal.bg });
  }

  if (t >= FROM_S) {
    const step = Math.floor((t - FROM_S) / STEP_S);
    cover(s, covers, album.cover_url, left, top, size, { res: step < STEPS.length ? STEPS[step] : size, pal });
  }

  if (!done) return;

  chunky(s, "1", 6, top + 5, 4, { face: pal.hot, side: pal.b, depth: 3 });
  chunky(s, score(album.score), 122, top + size - 24, 5, { face: pal.hot, side: pal.bg, edge: [255, 255, 255], depth: 4, align: "right" });

  const big = album.name.length <= 12;
  const y = s.front.block(album.name, 6, top + size + 19, 114, { size: big ? 17 : 11, weight: 700, lines: 2, color: pal.bg, shown: chars(t, DONE_S + 0.6) });
  if (album.artist) s.front.type(album.artist.slice(0, chars(t, DONE_S + 1.4)), 6, y + 2, { size: 4, mono: true, upper: true, spacing: 0.2, color: pal.bg, max: 114 });
}
