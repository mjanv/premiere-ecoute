import { PALETTES, backdrop, chars, chunky, skyline, span, stepped } from "../kit";

// Your year in music: a skyline of dots rises while the albums are counted, then the poster cuts
// to another colour and counts the minutes.

export const duration = 11;

const CUT_S = 5.4;

export function draw(s, card, t, { labels }) {
  const { albums, minutes } = card.data;
  const second = minutes > 0 && t >= CUT_S;
  const pal = second ? PALETTES.ember : PALETTES.sea;
  const since = second ? t - CUT_S : t;
  const value = second ? minutes : albums;
  const label = second ? labels.minutes(minutes) : labels.albums(albums);
  const align = second ? "right" : "left";
  const x = second ? 120 : 6;

  backdrop(s, pal);

  const rise = stepped(1 - Math.pow(1 - span(since, 0.5, 3), 3), 30);
  const scale = Math.max(3, Math.min(9, Math.floor(114 / (String(value).length * 6 - 1))));
  const y = 30;
  const ground = y + 7 * scale + 38;

  s.back.glow(second ? 84 : 42, y + 4 * scale, 66, [pal.a, pal.dim], { alpha: 0.4 + 0.6 * rise });

  // The skyline climbs with the count, under the figure
  skyline(s, 0, ground, s.w, s.h - 14 - ground, t, 0.1 + 0.6 * rise, pal, second ? 5 : 2);

  chunky(s, String(Math.round(value * rise)), x, y, scale, { face: pal.hot, side: pal.a, edge: [255, 255, 255], depth: 4, align });
  s.front.type(label.slice(0, chars(since, 1.2, 14)), x, y + 7 * scale + 8, { size: 18, color: pal.b, align });
}
