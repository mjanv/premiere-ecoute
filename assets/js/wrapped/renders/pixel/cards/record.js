import { backdrop, chars, chunky, cover, disc, heading, lift, score, span, stepped } from "../kit";

// A record coming out of its sleeve, shared by the top track and the top single: the cover stands
// whole, then breaks into strips that slide away and leave the record spinning over a halo.

export function record(s, entry, t, { pal, covers, label, hole = 1.5, labelSize = 0.42 }) {
  // Edge to edge where the screen is tall enough
  const size = Math.min(s.w, s.h - 140);
  const left = Math.round((s.w - size) / 2);

  backdrop(s, pal);
  const top = heading(s, label, t, pal) - lift(s);
  const away = stepped(span(t, 2.6, 5.2), 12);

  s.back.glow(63, top + size / 2, size * 1.05, s.light ? [pal.b, pal.dim] : [pal.b, pal.a, pal.dim], { alpha: span(t, 2.6, 5.2) });
  if (t >= 0.9) disc(s, covers, entry.cover_url, 63, top + size / 2, Math.floor(size / 2) - 1, Math.floor(t * 12) * 0.22, { pal, hole, label: labelSize });
  if (t >= 0.9 && away < 1) cover(s, covers, entry.cover_url, left, top, size, { mode: "slices", amount: away * 1.6, pal });

  const big = entry.name.length <= 12;
  let y = s.front.block(entry.name, 6, top + size + 8, 114, { size: big ? 17 : 11, weight: 700, lines: 2, color: pal.hot, shown: chars(t, 5.4) });
  if (entry.artist) {
    s.front.type(entry.artist.slice(0, chars(t, 6.2)), 6, y + 1.5, { size: 3.8, mono: true, upper: true, spacing: 0.2, color: s.light ? pal.a : pal.b, max: 114 });
    y += 8;
  }

  if (t >= 7) chunky(s, score(entry.score), 6, Math.round(y + 5), 4, { face: pal.b, side: pal.a, depth: 3 });
}
