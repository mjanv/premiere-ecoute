import { mix } from "../screen";
import { PALETTES, backdrop, chunky, heading, lift, span, stepped } from "../kit";

// Your months: the busiest month in chunky letters, then the year as twelve columns of dots
// growing from the ground, the busiest one lit from behind.

export const duration = 10;

export function draw(s, card, t, { labels }) {
  const pal = PALETTES.mint;
  const { months, busiest } = card.data;
  const peak = Math.max(...months, 1);
  const name = labels.months[busiest - 1];
  const scale = Math.max(2, Math.min(4, Math.floor(114 / (name.length * 6 - 1))));

  backdrop(s, pal);
  const start = heading(s, labels.busiest_month, t, pal) - lift(s);
  if (t >= 1.2) chunky(s, name, 6, start, scale, { face: pal.hot, side: pal.b, edge: [255, 255, 255], depth: 3 });

  const top = start + 7 * scale + 20;
  const ground = s.h - 24;
  const room = ground - top;
  const small = { size: 3.6, mono: true, upper: true, align: "center" };

  months.forEach((count, index) => {
    const x = 4 + index * 10;
    const lit = index + 1 === busiest;
    const grown = stepped(span(t, 2 + index * 0.14, 3.6 + index * 0.14), 10);
    const height = Math.round(Math.max(2, (count / peak) * room) * grown);

    if (lit) s.back.fade(x - 1, top - 10, 10, room + 10, pal.b, 0, 0.5 * grown);

    for (let j = 0; j < room; j++) {
      for (let i = 0; i < 8; i++) {
        const px = x + i;
        const py = ground - 1 - j;
        if ((px + py) % 2) continue;
        if (j >= height) s.px(px, py, mix(pal.bg, pal.dim, 0.7));
        else if (height - j <= 2) s.px(px, py, lit ? [255, 255, 255] : pal.hot);
        else s.px(px, py, lit ? pal.hot : j % 4 < 2 ? pal.a : mix(pal.a, pal.b, 0.5));
      }
    }

    if (count > 0 && grown >= 1) s.front.type(String(count), x + 4, ground - height - 6, { ...small, color: lit ? pal.hot : pal.b });
    s.front.type(labels.months[index][0], x + 4, ground + 2.5, { ...small, color: pal.hot, alpha: lit ? 1 : 0.55 });
  });
}
