import { PALETTES, backdrop, chars, checker, heading, span, stepped } from "../kit";

// Your rooms: the streamers come one at a time, the first one loudest, each with a band of
// checkers as long as the sessions spent there.

export const duration = 10;

export function draw(s, card, t, { labels }) {
  const pal = PALETTES.sea;
  const rooms = card.data.rooms;
  const most = Math.max(...rooms.map((room) => room.sessions), 1);

  backdrop(s, pal);
  let y = heading(s, labels.where_listened, t, pal);

  rooms.forEach((room, index) => {
    const first = index === 0;
    const since = t - 1.2 - index * 1.5;
    const base = first ? 22 : 11;
    const size = Math.min(base, (base * 114) / s.front.measure(room.name, { size: base, weight: 700 }));
    const band = first ? 8 : 4;

    if (since >= 0) {
      s.front.type(room.name, 6, y, { size, weight: 700, color: first ? pal.hot : pal.b });

      const width = Math.round(114 * (room.sessions / most) * stepped(span(since, 0.2, 1.1), 8));
      if (width > 0) checker(s, 6, Math.round(y + size + 2), width, band, 2, pal, Math.floor(t * 4), index);
      s.front.type(room.label.slice(0, chars(since, 0.5)), 6, y + size + band + 4.5, { size: 3.4, mono: true, upper: true, spacing: 0.2, color: pal.hot, alpha: 0.7 });
    }
    y += size + band + 15;
  });
}
