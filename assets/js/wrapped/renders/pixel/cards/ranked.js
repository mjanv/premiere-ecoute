import { backdrop, chars, cover, disc, heading, score, span, stepped } from "../kit";

// A ranked list from the second place down, shared by the next albums and the next tracks:
// a rank, a cover (or a small record), a name and a score, one row at a time.

export function ranked(s, entries, t, { pal, covers, label, records = false }) {
  backdrop(s, pal);
  const top = heading(s, label, t, pal);
  const row = Math.min(46, Math.floor((s.h - top - 14) / 4));

  entries.slice(0, 4).forEach((entry, index) => {
    const since = t - 1 - index * 1.5;
    if (since < 0) return;

    const y = top + index * row;
    s.front.rect(6, y - 3.5, 114, 0.3, pal.hot, 0.28);
    s.front.type(String(index + 2), 6, y + 7, { size: 15, weight: 700, color: pal.b });

    if (records) disc(s, covers, entry.cover_url, 34, y + 15, 15, Math.floor(t * 10) * 0.35, { pal, hole: 1 });
    else cover(s, covers, entry.cover_url, 19, y, 30, { mode: "tiles", amount: 1 - stepped(span(since, 0, 0.9), 6), pal });

    const below = s.front.block(entry.name, 55, y + 0.5, 65, { size: 6.6, weight: 700, lines: 2, color: pal.hot, shown: chars(since, 0.5) });
    if (entry.artist) {
      s.front.type(entry.artist.slice(0, chars(since, 0.9)), 55, below + 1.5, { size: 3.4, mono: true, upper: true, spacing: 0.2, color: pal.hot, alpha: 0.62, max: 65 });
    }

    if (since >= 1.1) {
      const style = { size: 5.4, mono: true, weight: 700 };
      const width = s.front.measure(score(entry.score), style) + 3.4;
      s.front.rect(120 - width, y + 21.4, width, 8.6, pal.b);
      s.front.type(score(entry.score), 118.3, y + 23, { ...style, color: pal.bg, align: "right" });
    }
  });
}
