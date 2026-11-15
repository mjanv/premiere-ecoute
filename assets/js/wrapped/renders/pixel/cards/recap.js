import { PALETTES, backdrop, brand, chars, chunky, clamp, cover, disc, span, stepped } from "../kit";

// Recap: the last poster. Its title and the year, the three covers of the top sharpening one after
// the other, their names, the track of the year, then the two figures.

export const duration = 12;
// This poster carries its own title, and the share and replay buttons take its foot
export const mark = false;
export const footer = false;

// Height kept at the foot for the buttons
const ACTIONS = 25;

export function draw(s, card, t, { year, owner, labels, covers, cards }) {
  const pal = PALETTES.ember;
  const { top, albums, minutes } = card.data;
  const track = cards.find((other) => other.type === "top_track")?.data.track;
  const ink = pal.hot;
  const small = { size: 3.4, mono: true, upper: true, spacing: 0.2, color: ink, alpha: 0.7, max: 114 };
  const row = s.h < 250 ? 13.5 : 16.5;

  // The blocks of the poster share what the screen leaves free between them
  const heights = [38 + (owner ? 9 : 0), 39, top.length * row, track ? 18 : 0, 24].filter(Boolean);
  const free = s.h - ACTIONS - 22 - heights.reduce((sum, height) => sum + height, 0);
  const gap = clamp(free / (heights.length - 1), 2, 12);
  let y = 22 + clamp((free - gap * (heights.length - 1)) / 2, 0, 20);

  backdrop(s, pal);

  // Title: Premiere Ecoute Wrapped, and the year
  const title = 6.4;
  const width = s.front.measure("Premiere Ecoute Wrapped", { size: title, weight: 700 }) + title * 1.38;
  brand(s, 63 - width / 2, y, title, " Wrapped");
  s.back.glow(63, y + 22, 70, [pal.a, pal.dim], { alpha: 0.7 });
  chunky(s, String(year), 63, Math.round(y + 9), 4, { face: pal.hot, side: pal.b, edge: [255, 255, 255], depth: 3, align: "center" });
  if (owner) s.front.type(owner, 63, y + 41, { size: 6.4, weight: 700, color: ink, align: "center", max: 114 });
  y = Math.round(y + heights[0] + gap);

  // The top three
  top.forEach((album, index) => {
    const since = t - 0.8 - index * 0.9;
    const x = 6 + index * 39;
    if (since < 0) return s.dither(x, y, 36, 36, null, pal.dim, 0.5);

    const res = [1, 2, 4, 8, 16, 36][Math.min(5, Math.floor(since / 0.16))];
    cover(s, covers, album.cover_url, x, y, 36, { res, pal });
    s.rect(x, y + 30, 9, 9, ink);
    s.front.type(String(index + 1), x + 4.5, y + 31.8, { size: 5.6, weight: 700, color: pal.bg, align: "center" });
  });
  y += 39 + gap;

  top.forEach((album, index) => {
    const since = t - 3.4 - index * 0.6;
    s.front.block(album.name, 6, y, 114, { size: 6.8, weight: 700, lines: 1, color: ink, shown: chars(since, 0) });
    if (album.artist) s.front.type(album.artist.slice(0, chars(since, 0.3)), 6, y + 8.2, small);
    y += row;
  });
  y += gap;

  // The track of the year, as a small record
  if (track) {
    const since = t - 5.2;
    if (since >= 0) {
      disc(s, covers, track.cover_url, 15, Math.round(y + 9), 9, Math.floor(t * 10) * 0.35, { pal, hole: 1 });
      s.front.type(labels.track_of_year.slice(0, chars(since, 0, 40)), 29, y + 0.5, { ...small, color: pal.b, alpha: 1, max: 91 });
      s.front.block(track.name, 29, y + 5.2, 91, { size: 6.8, weight: 700, lines: 1, color: ink, shown: chars(since, 0.3) });
      if (track.artist) s.front.type(track.artist.slice(0, chars(since, 0.6)), 29, y + 13.4, { ...small, max: 91 });
    }
    y += 18 + gap;
  }

  if (t < 6.2) return;

  const rise = stepped(span(t, 6.2, 7.6), 14);
  const base = Math.round(y + 3);
  s.front.rect(6, y - gap / 2, 114, 0.4, ink, 0.6);
  const first = chunky(s, String(Math.round(albums * rise)), 6, base, 2, { face: pal.b, side: pal.dim, depth: 2 });
  s.front.type(labels.albums(albums), 6, base + 17, { size: 5.6, color: ink });
  if (minutes > 0) {
    const x = Math.max(60, 6 + first + 14);
    chunky(s, String(Math.round(minutes * rise)), x, base, 2, { face: pal.hot, side: pal.dim, depth: 2 });
    s.front.type(labels.minutes(minutes), x, base + 17, { size: 5.6, color: ink });
  }
}
