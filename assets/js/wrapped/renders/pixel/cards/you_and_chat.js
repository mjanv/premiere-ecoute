import { PALETTES, backdrop, chars, chunky, cover, heading, lift, score, span, stepped } from "../kit";

// You and the chat, in two times. First the album where you went your own way, with a ≠ blinking
// between the two scores. Then the poster cuts to another colour: the album where you heard the same thing, with an =.

export const duration = 13;

const CUT_S = 6.5;

export function draw(s, card, t, { labels, covers }) {
  const second = t >= CUT_S;
  const pal = second ? PALETTES.sea : PALETTES.plum;
  const entry = second ? card.data.closest : card.data.furthest;
  const since = second ? t - CUT_S : t;
  const size = Math.min(86, s.h - 152 - lift(s));

  backdrop(s, pal);
  const top = heading(s, second ? labels.same_thing : labels.own_way, since, pal);

  if (since >= 1) cover(s, covers, entry.cover_url, 6, top, size, { mode: "tiles", amount: 1 - stepped(span(since, 1, 2), 6), pal });

  let y = top + size + 6;
  y = s.front.block(entry.name, 6, y, 114, { size: 9, weight: 700, lines: 2, color: pal.hot, shown: chars(since, 1.6) });
  if (entry.artist) {
    s.front.type(entry.artist.slice(0, chars(since, 2.2)), 6, y + 1.5, { size: 3.6, mono: true, upper: true, spacing: 0.2, color: pal.b, max: 114 });
    y += 8;
  }
  if (since < 3) return;

  // Two scores side by side, as large as the pair allows
  const you = score(entry.you);
  const chat = score(entry.chat);
  const scale = Math.max(2, Math.min(4, Math.floor(110 / ((you.length + chat.length) * 6 - 2))));
  const row = Math.round(y + 6);
  const small = { size: 3.6, mono: true, upper: true, spacing: 0.2, color: pal.hot, alpha: 0.75 };

  s.front.type(labels.you, 6, row, small);
  chunky(s, you, 6, row + 7, scale, { face: pal.hot, side: pal.a, edge: [255, 255, 255], depth: 3 });
  if (since < 3.6) return;

  s.front.type(labels.chat, 120, row, { ...small, align: "right" });
  chunky(s, chat, 120, row + 7, scale, { face: pal.b, side: pal.dim, depth: 3, align: "right" });

  // The sign blinks for a moment, then stays
  if (since >= 4.2 && (since >= 5.2 || Math.floor(since * 6) % 2)) s.text(second ? "=" : "≠", 63, row - 10, { scale: 2, color: pal.hot, align: "center" });
}
