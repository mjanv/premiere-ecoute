// Chat votes as a discreet night sky behind the session overlay. Every vote lights a
// pixel star that flashes and fades (twinkle), then settles as a faint dot that stays
// until the next track (constellation). Great votes cross the sky first as a shooting
// star with a dithered trail along a slightly curved path, and settle where they land.
// The server pushes "votes_cast" with values in 0..1 (vote position on the session's
// scale) and "stars_reset" on a new track. Votes arrive in batches (up to 5, or after
// 1 s), so each batch is spread over SPREAD ms.
// Colours: low votes lean to the secondary colour, high votes to the primary (read
// from the overlay root's data-primary/data-secondary). In great mode the liquid layer
// multiplies the whole widget, stars included, so they are drawn in greys and take the
// gradient's colours. The canvas sits behind the widget content (z-index -1), so stars
// pass under borders, text and the progress bar.
import { fitCanvas, rgb } from "./overlay_canvas";

// Tuning knobs
const UNIT = 80; // pixel unit = widget height / UNIT (star pixels stay chunky on a small widget)
const SPREAD = 1000; // ms over which a batch of votes is spread
const TWINKLE = 2200; // ms from flash to settled dot
const PEAK = 0.9; // brightness of a star at its flash (0..1)
const REST = 0.22; // brightness of a settled star, as a share of its peak
const SHOOTING = 0.9; // votes at or above this value shoot first
const FLIGHT = 1500; // ms for a shooting star to cross
const TRAIL = 14; // trail length, in pixel units
const TRAVEL = [0.2, 0.4]; // distance crossed, as a share of the widget width
const BEND = [0.1, 0.3]; // sideways bow of the path, as a share of its length (either side)
const ENTRY = [0.25, 0.7]; // angle off straight inward at which a shooting star enters, in radians (either side)
const BORDERS = ["top", "bottom", "left", "right"];
const MAX_STARS = 1500; // oldest settled stars are dropped past this

const ease = (t) => 1 - Math.pow(1 - t, 2);

const between = ([a, b]) => a + Math.random() * (b - a);
const sign = () => (Math.random() < 0.5 ? -1 : 1);

// Path of a shooting star: it enters from just outside a random border, at an angle,
// and lands inside the widget, bowing to one side. Computed in units of the widget
// width (aspect = height / width) so angles and bows are not stretched, then returned
// as shares of the width and height: { from, bend, x, y }.
function flight(aspect) {
  const border = BORDERS[Math.floor(Math.random() * BORDERS.length)];
  const vertical = border === "top" || border === "bottom";
  const inward = { top: [0, 1], bottom: [0, -1], left: [1, 0], right: [-1, 0] }[border];
  const tilt = sign() * between(ENTRY);
  const dir = [
    inward[0] * Math.cos(tilt) - inward[1] * Math.sin(tilt),
    inward[0] * Math.sin(tilt) + inward[1] * Math.cos(tilt),
  ];
  const out = 0.02 * aspect; // start just outside the border
  const from = vertical
    ? [between([0.05, 0.95]), border === "top" ? -out : aspect + out]
    : [border === "left" ? -out : 1 + out, between([0.1, 0.9]) * aspect];
  // Length: the travel range, shortened so the landing stays inside the widget.
  let length = between(TRAVEL);
  const inside = (l) => {
    const x = from[0] + dir[0] * l;
    const y = from[1] + dir[1] * l;
    return x > 0.02 && x < 0.98 && y > 0.05 * aspect && y < 0.95 * aspect;
  };
  while (length > 0.02 && !inside(length)) length *= 0.9;
  if (!inside(length)) length = (vertical ? 0.5 * aspect : 0.15) / Math.max(0.3, Math.abs(dir[vertical ? 1 : 0]));
  const to = [from[0] + dir[0] * length, from[1] + dir[1] * length];
  const bow = sign() * between(BEND) * length;
  const bend = [(from[0] + to[0]) / 2 - dir[1] * bow, (from[1] + to[1]) / 2 + dir[0] * bow];
  const norm = ([x, y]) => ({ x, y: y / aspect });
  const land = norm(to);
  return { from: norm(from), bend: norm(bend), x: Math.min(0.98, Math.max(0.02, land.x)), y: Math.min(0.95, Math.max(0.05, land.y)) };
}

// Point at k (0..1) on the star's quadratic curve, in canvas pixels.
function along(s, k, w, h) {
  const a = (1 - k) * (1 - k);
  const b = 2 * k * (1 - k);
  const c = k * k;
  return [(a * s.from.x + b * s.bend.x + c * s.x) * w, (a * s.from.y + b * s.bend.y + c * s.y) * h];
}

function mix(a, b, k) {
  return a.map((v, i) => v + (b[i] - v) * k);
}

function shade(colour, level) {
  return `rgb(${colour.map((v) => Math.round(Math.min(255, v * level))).join(",")})`;
}

export const StarField = {
  mounted() {
    this.stars = [];
    this.handleEvent("votes_cast", ({ values }) => this.cast(values));
    this.handleEvent("stars_reset", () => {
      this.stars = [];
      this.kick();
    });
    this.observer = new ResizeObserver(() => {
      fitCanvas(this.el);
      this.kick();
    });
    this.observer.observe(this.el);
  },

  destroyed() {
    this.gone = true;
    this.observer?.disconnect();
    if (this.raf) cancelAnimationFrame(this.raf);
  },

  colours() {
    const root = this.el.closest("[data-overlay-root]");
    return [rgb(root?.dataset.secondary, "#ffffff"), rgb(root?.dataset.primary, "#ffffff")];
  },

  cast(values) {
    const now = performance.now();
    const step = SPREAD / Math.max(1, values.length);
    values.forEach((value, i) => {
      const v = Math.min(1, Math.max(0, Number(value) || 0));
      const at = now + i * step + Math.random() * step * 0.8;
      const star = { value: v, at, x: Math.random(), y: Math.random(), big: Math.random() < 0.25 };
      if (v >= SHOOTING) {
        Object.assign(star, flight(this.el.height / this.el.width || 0.3));
        star.seed = Math.random() * 1000;
        star.big = true;
      }
      this.stars.push(star);
    });
    if (this.stars.length > MAX_STARS) this.stars.splice(0, this.stars.length - MAX_STARS);
    this.kick();
  },

  kick() {
    if (!this.raf && !this.gone) this.raf = requestAnimationFrame((t) => this.frame(t));
  },

  frame(now) {
    this.raf = null;
    const canvas = this.el;
    const ctx = canvas.getContext("2d");
    const w = canvas.width;
    const h = canvas.height;
    const unit = Math.max(1, Math.round(h / UNIT));
    const root = this.el.closest("[data-overlay-root]");
    const great = !!root?.querySelector("#overlay-liquid");
    const [low, high] = great ? [[200, 200, 200], [255, 255, 255]] : this.colours();
    const px = (x, y, s = 1) => ctx.fillRect(Math.round(x / unit) * unit, Math.round(y / unit) * unit, unit * s, unit * s);
    let active = false;

    ctx.clearRect(0, 0, w, h);
    for (const s of this.stars) {
      const colour = mix(low, high, s.value);
      const dim = 0.55 + 0.45 * s.value; // low votes are dimmer
      let t = now - s.at;
      if (t < 0) {
        active = true;
        continue;
      }

      if (s.from) {
        if (t < FLIGHT) {
          active = true;
          const k = ease(t / FLIGHT);
          const [hx, hy] = along(s, k, w, h);
          const [ex, ey] = along(s, 1, w, h);
          const [fx, fy] = along(s, 0, w, h);
          // Parameter step of about one pixel unit along the path.
          const dk = unit / (Math.hypot(ex - fx, ey - fy) || 1);
          // Trail: pixels behind the head along the curve, fading and breaking up.
          for (let i = TRAIL; i > 0; i--) {
            const f = i / TRAIL;
            const r = Math.abs(Math.sin((i + 1) * 12.9898 + s.seed) * 43758.5453) % 1;
            if (r < f * 0.8 || k - i * dk < 0) continue;
            const [x, y] = along(s, k - i * dk, w, h);
            ctx.fillStyle = shade(colour, PEAK * dim * (1 - f));
            px(x, y);
          }
          ctx.fillStyle = shade([255, 255, 255], PEAK * dim);
          px(hx, hy);
          continue;
        }
        t -= FLIGHT;
      }

      // Twinkle: quick flash, then decay to the resting level.
      const x = s.x * w;
      const y = s.y * h;
      let level = REST;
      if (t < TWINKLE) {
        active = true;
        const rise = Math.min(1, t / 120);
        const fall = Math.pow(1 - t / TWINKLE, 2);
        level = rise * (REST + (1 - REST) * fall);
        // A cross at the flash for big stars.
        if (s.big && fall > 0.35) {
          ctx.fillStyle = shade(colour, PEAK * dim * fall * 0.6);
          px(x - unit, y);
          px(x + unit, y);
          px(x, y - unit);
          px(x, y + unit);
        }
      }
      ctx.fillStyle = shade(colour, PEAK * dim * level);
      px(x, y);
    }

    if (active) this.kick();
  },
};
