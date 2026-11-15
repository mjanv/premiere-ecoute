import { css } from "../poster";
import { PALETTES, backdrop, beats, burst, chars, checker, chunky, soft } from "../kit";
import { mix } from "../screen";

// Start screen: a flipbook of posters for the year. A new poster in a new palette every POSTER_S
// seconds, while the introduction is typed underneath, one sentence at a time.

const ORDER = ["plum", "sea", "ember", "mint"];
const SENTENCE_S = 6.5;
const POSTER_S = 1.2;
// The introduction, and the room the start button takes at the foot of the screen
const INTRO = { size: 6.2, leading: 1.26, lines: 6 };
const BUTTON = 33;

// A tagline cut in two lines of about the same number of words
const halves = (text) => {
  const words = text.split(" ");
  const cut = Math.ceil(words.length / 2);
  return [words.slice(0, cut).join(" "), words.slice(cut).join(" ")];
};

// A halo across the dark, and three small words
function glow(s, t, pal, { top, height, lines }) {
  const mid = top + height / 2;
  const type = { size: 3.6, mono: true, upper: true, spacing: 0.2 };

  s.back.glow(63, mid, 56 + Math.sin(t * 2) * 1.5, [pal.hot, pal.b, pal.a], { angle: -0.62 + Math.sin(t * 1.3) * 0.04 });
  s.front.type(lines[0], 63, mid - 2, { ...type, color: pal.bg, align: "center" });
  s.front.type(`${lines[1]}.`, 120, mid - 2, { ...type, color: pal.hot, align: "right" });
  s.front.type("+", 6, mid - 2, { ...type, color: pal.hot });
}

// The tagline set large over a panel of light, with a burst of pixels
function headline(s, t, pal, { top, height, lines }) {
  s.back.panel(0, top + height * 0.42, s.w, s.h, pal);
  burst(s, 63, Math.round(top + height * 0.72), Math.round(Math.min(40, height * 0.27)), t, { a: pal.bg, b: pal.a });
  s.front.type(lines[0], 63, top + 4, { size: 18, color: pal.hot, align: "center", max: 114 });
  s.front.type(`${lines[1]}.`, 63, top + 22, { size: 18, color: pal.hot, align: "center", max: 114 });
}

// The year in blocks pushed out of the poster
function digits(s, t, pal, { top, height, year }) {
  // As large as the poster allows: two digits per line
  const scale = Math.max(5, Math.min(9, Math.floor((height - 26) / 14)));
  const y = top + Math.round((height - 14 * scale - 5) / 2);
  const wobble = Math.round(Math.sin(t * 3));

  chunky(s, year.slice(0, 2), 63 + wobble, y, scale, { face: pal.hot, side: pal.a, edge: mix(pal.hot, [255, 255, 255], 0.5), align: "center", depth: 5 });
  chunky(s, year.slice(2), 63 - wobble, y + 7 * scale + 5, scale, { face: pal.b, side: pal.dim, edge: pal.hot, align: "center", depth: 5 });
}

// Four rows: a word on one side, a band of checkers on the other
function checkers(s, _t, pal, { top, height, lines, year, beat }) {
  const row = height / 4;
  const words = [year, "Wrapped", lines[0], lines[1]];

  words.forEach((word, index) => {
    const y = top + index * row;
    const left = index % 2 === 0;
    checker(s, left ? 76 : 0, Math.round(y + 2), left ? 50 : 60, Math.round(row - 4), 3, pal, beat, index);
    s.front.type(word, left ? 6 : 120, y + row / 2 - 5.5, { size: 11, mono: true, upper: true, color: pal.hot, align: left ? "left" : "right", max: left ? 66 : 56 });
  });
}

// One line, over and over, a sweep of colour running down it
function repeated(s, t, pal, { top, height, lines, year }) {
  const c = s.front.ctx;
  const text = `${lines.join(" ")}. ${year}.`.toUpperCase();
  const count = Math.max(6, Math.floor(height / 8.5));
  const sweep = (t * 0.6) % 1;

  s.front.font({ size: 5.6, mono: true });
  c.textAlign = "left";
  c.textBaseline = "alphabetic";
  for (let i = 0; i < count; i++) {
    const k = (i / count + sweep) % 1;
    const gradient = c.createLinearGradient(6, 0, 120, 0);
    gradient.addColorStop(0, css(pal.a));
    gradient.addColorStop(Math.max(0.05, 1 - k), css(pal.b));
    gradient.addColorStop(1, css(soft(pal, 0.7)));
    c.fillStyle = gradient;
    c.fillText(text, 6, top + 8 + i * 8.5, 114);
  }
}

// The edition up the side, a panel of light and two bursts
function split(s, t, pal, { top, height, lines, year }) {
  const bottom = top + height;

  s.back.panel(52, top + height * 0.5, s.w, s.h, pal);
  burst(s, 90, Math.round(top + height * 0.27), Math.round(Math.min(32, height * 0.24)), t, pal);
  burst(s, 88, Math.round(top + height * 0.78), Math.round(Math.min(22, height * 0.17)), t + 1, { a: pal.bg, b: pal.a });
  s.front.vertical(`Wrapped ${year}`, 8, bottom - 4, { size: 17, mono: true, upper: true, color: pal.hot, max: height - 10 });
  s.front.vertical(lines.join(" "), 30, bottom - 4, { size: 6.4, color: pal.hot, max: height - 10 });
}

const POSTERS = [glow, headline, digits, checkers, repeated, split];

export function draw(s, _card, t, { labels, year, owner }) {
  const beat = Math.max(0, beats(t, 0, POSTER_S));
  const pal = PALETTES[ORDER[beat % ORDER.length]];
  const top = 24;
  // The posters take all the height the longest sentence of the introduction leaves
  const rows = Math.max(...labels.intro.map((sentence) => s.front.wrap(sentence, 114, INTRO.lines, INTRO).length));
  const band = Math.ceil(5 + (owner ? 12 : 0) + rows * INTRO.size * INTRO.leading + 3 + BUTTON);
  const bottom = s.h - band;

  backdrop(s, pal);
  POSTERS[beat % POSTERS.length](s, t, pal, { top, height: bottom - top, lines: halves(labels.tagline), year: String(year), beat });

  // The posters end in the dark, where the introduction is written
  s.front.fade(0, bottom - 16, s.w, 16, pal.bg, 0, 1);
  s.front.rect(0, bottom, s.w, band, pal.bg);

  let y = bottom + 5;
  if (owner) y += s.front.type(owner, 6, y, { size: 9, weight: 700, color: pal.hot, max: 114 }) ? 12 : 0;

  const sentences = labels.intro;
  const turn = Math.floor(t / SENTENCE_S) % sentences.length;
  const since = t - Math.floor(t / SENTENCE_S) * SENTENCE_S;
  s.front.block(sentences[turn], 6, y, 114, { ...INTRO, color: soft(pal, 0.9), shown: chars(since, 0.3, 30) });
}
