import { PALETTES, backdrop, chars, chunky, cover, heading, lift, span, stepped } from "../kit";

// First vote: the cover of the first album of the year comes together from sliding strips over a
// halo, then its name is typed and the day lands under it.

export const duration = 10;

export function draw(s, card, t, { labels, covers }) {
  const pal = PALETTES.plum;
  const { album, date } = card.data;
  const [, month, day] = date.split("-").map(Number);
  // Edge to edge where the screen is tall enough
  const size = Math.min(s.w, s.h - 150);
  const left = Math.round((s.w - size) / 2);

  backdrop(s, pal);
  const top = heading(s, labels.started_with, t, pal) - lift(s);
  const together = span(t, 1.2, 4.6);

  s.back.glow(63, top + size / 2, size * 1.05, [pal.b, pal.a, pal.dim], { alpha: together });
  if (t >= 1.2) cover(s, covers, album.cover_url, left, top, size, { mode: "slices", amount: 1 - stepped(together, 12), pal });

  let y = top + size + 7;
  y = s.front.block(album.name, 6, y, 114, { size: 10, weight: 700, lines: 2, color: pal.hot, shown: chars(t, 4.8) });
  if (album.artist) {
    s.front.type(album.artist.slice(0, chars(t, 5.6)), 6, y + 1.5, { size: 3.8, mono: true, upper: true, spacing: 0.2, color: pal.b, max: 114 });
    y += 8;
  }

  if (t >= 6.6) {
    const width = chunky(s, String(day), 6, Math.round(y + 6), 4, { face: pal.hot, side: pal.a, edge: [255, 255, 255], depth: 3 });
    s.front.type(labels.months[month - 1].slice(0, chars(t, 6.9, 16)), 6 + width + 9, y + 13, { size: 16, color: pal.b, max: 105 - width });
  }
}
