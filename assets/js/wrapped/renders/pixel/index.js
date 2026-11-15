import { Sound, mute } from "../../sound";
import { Covers } from "./covers";
import { chrome } from "./kit";
import { fonts } from "./poster";
import { Screen } from "./screen";
import { scene, start } from "./cards";

// Pixel render of a Wrapped. Everything is drawn on one canvas: posters whose pictures, records and
// big figures are made of pixels, under real type. The server only sends the cards as data, and the buttons. This hook runs the playback (navigation,
// auto-advance, pause, sound) and asks the scene of the current card for a frame. Scenes live in ./cards.

const HOLD_MS = 220;
const SWIPE_PX = 40;
const DISSOLVE_MS = 480;
// With reduced motion every scene is shown as it ends, and nothing moves
const SETTLED_S = 60;
// The start screen is a flipbook: with reduced motion it stays on one poster, its introduction written
const START_SETTLED_S = 6.4;

const reducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;

// Every cover a card mentions, however deep
const coverUrls = (value) =>
  value && typeof value === "object" ? Object.entries(value).flatMap(([key, item]) => (key === "cover_url" && item ? [item] : coverUrls(item))) : [];

export const WrappedPlayerPixel = {
  mounted() {
    const el = this.el;
    const text = JSON.parse(el.dataset.labels);

    this.cards = JSON.parse(el.dataset.cards);
    this.context = {
      year: Number(el.dataset.year),
      owner: el.dataset.owner || null,
      covers: new Covers(),
      cards: this.cards,
      labels: {
        ...text,
        albums: (count) => (count === 1 ? text.album : text.albums),
        minutes: (count) => (count === 1 ? text.minute : text.minutes),
      },
    };
    coverUrls(this.cards).forEach((url) => this.context.covers.load(url));

    this.screen = new Screen(el.querySelector("[data-screen]"));
    fonts();
    this.sound = new Sound();
    this.previews = [];
    this.index = -1;
    this.elapsed = 0;
    this.clock = 0;
    this.paused = false;
    this.begun = false;
    this.reduced = reducedMotion();

    // Preview URLs arrive once the page is live: they are signed, short-lived and never rendered
    this.handleEvent("wrapped:previews", ({ urls }) => {
      this.previews = urls;
      if (!this.begun) return;

      this.el.querySelector("[data-mute]").hidden = !urls.some(Boolean);
      // Play the latest preview at or before the current card
      this.sound.play(urls.slice(0, this.index + 1).filter(Boolean).pop());
    });

    this.on(el.querySelector("[data-begin]"), "click", () => this.begin());
    this.on(el.querySelector("[data-pause]"), "click", () => this.togglePause());
    this.on(el.querySelector("[data-mute]"), "click", () => this.toggleMute());
    this.on(el.querySelector("[data-replay]"), "click", () => this.show(0));
    this.on(el.querySelector("[data-share]"), "click", (event) => this.share(event.currentTarget));

    for (const [selector, step] of [["[data-prev]", -1], ["[data-next]", 1]]) {
      const zone = el.querySelector(selector);
      this.on(zone, "pointerdown", (event) => this.press(event));
      this.on(zone, "pointerup", (event) => this.release(event, step));
      this.on(zone, "pointercancel", () => this.cancelPress());
      // Keyboard and assistive tech activate the zone without pointer events
      this.on(zone, "click", (event) => event.detail === 0 && this.go(step));
    }

    this.onKey = (event) => {
      if (this.index < 0) return;
      if (event.key === "ArrowRight") this.go(1);
      else if (event.key === "ArrowLeft") this.go(-1);
      else if (event.key === " " && event.target === document.body) {
        event.preventDefault();
        this.togglePause();
      }
    };
    this.onVisibility = () => {
      this.last = performance.now();
    };
    window.addEventListener("keydown", this.onKey);
    document.addEventListener("visibilitychange", this.onVisibility);

    this.frame = (now) => {
      this.raf = requestAnimationFrame(this.frame);
      const delta = Math.min(now - (this.last || now), 100);
      this.last = now;
      if (document.hidden) return;

      this.clock += delta;
      if (this.index >= 0 && !this.paused && !this.held && !this.reduced && this.frozen === undefined) {
        this.elapsed += delta;
        const length = scene(this.cards[this.index]).duration * 1000;
        if (this.elapsed >= length && this.index < this.cards.length - 1) this.show(this.index + 1);
      }
      this.draw(now);
    };
    this.raf = requestAnimationFrame(this.frame);

    // Development: ?card=<index>&at=<seconds> opens one card frozen at a moment
    const query = new URLSearchParams(window.location.search);
    if (query.has("card")) {
      this.begin();
      this.show(Math.min(this.cards.length - 1, Math.max(0, Number(query.get("card")) || 0)));
      this.changed = -Infinity;
      if (query.has("at")) this.frozen = Number(query.get("at")) || 0;
    } else if (query.has("at")) {
      this.frozen = Number(query.get("at")) || 0;
    }
  },

  destroyed() {
    cancelAnimationFrame(this.raf);
    window.removeEventListener("keydown", this.onKey);
    document.removeEventListener("visibilitychange", this.onVisibility);
    this.sound.destroy();
  },

  on(target, event, handler) {
    target?.addEventListener(event, handler);
  },

  // Seconds since the current scene began
  time() {
    if (this.frozen !== undefined) return this.frozen;
    if (this.index < 0) return this.reduced ? START_SETTLED_S : this.clock / 1000;
    return this.reduced ? SETTLED_S : this.elapsed / 1000;
  },

  draw(now) {
    const s = this.screen;
    const card = this.cards[this.index];
    const t = this.time();

    const current = card ? scene(card) : start;

    s.begin();
    current.draw(s, card, t, this.context);
    chrome(s, this.context.year, card && current.footer !== false ? { index: this.index, count: this.cards.length } : null, current.mark !== false);
    s.compose();

    if (!this.reduced) s.dissolve((now - this.changed) / DISSOLVE_MS);
    if (card) this.progress(s);

    // The share and replay buttons belong to the end of the recap
    const actions = this.el.querySelector("[data-actions]");
    if (actions) actions.hidden = !(card && card.type === "recap" && t >= 7.6);
  },

  // One segment per card along the top of the screen
  progress(s) {
    const count = this.cards.length;
    const gap = 1;
    const width = (s.w - 12 - (count - 1) * gap) / count;
    const done = this.reduced ? 1 : Math.min(1, this.elapsed / (scene(this.cards[this.index]).duration * 1000));

    for (let i = 0; i < count; i++) {
      const x = 6 + i * (width + gap);
      s.back.rect(x, 3.4, width, 1, s.ink, 0.28);
      if (i <= this.index) s.back.rect(x, 3.4, i < this.index ? width : width * done, 1, s.ink);
    }
  },

  begin() {
    this.begun = true;

    this.el.querySelector("[data-begin]").hidden = true;
    for (const selector of ["[data-pause]", "[data-prev]", "[data-next]"]) this.el.querySelector(selector).hidden = false;
    this.el.querySelector("[data-mute]").hidden = !this.previews.some(Boolean);
    // Without auto-advance there is nothing to pause
    if (this.reduced) this.el.querySelector("[data-pause]").hidden = true;

    this.pushEvent("started", {});
    this.show(0);
  },

  go(step) {
    const next = this.index + step;
    if (next < 0) return this.show(0);
    if (next >= this.cards.length) return;
    this.show(next);
  },

  show(index) {
    // The outgoing frame dissolves into the new scene
    this.screen.snapshot();
    this.changed = performance.now();
    this.index = index;
    this.elapsed = 0;

    if (this.paused) this.togglePause();
    this.sound.play(this.previews[index]);
  },

  press(event) {
    this.pressX = event.clientX;
    this.holdTimer = setTimeout(() => this.setHeld(true), HOLD_MS);
  },

  release(event, step) {
    clearTimeout(this.holdTimer);
    const held = this.held;
    const swipe = event.clientX - this.pressX;
    this.setHeld(false);

    if (Math.abs(swipe) > SWIPE_PX) this.go(swipe < 0 ? 1 : -1);
    else if (!held) this.go(step);
  },

  cancelPress() {
    clearTimeout(this.holdTimer);
    this.setHeld(false);
  },

  // Holding the screen freezes the story, like any stories player
  setHeld(held) {
    if (this.held === held) return;
    this.held = held;
    this.sound.freeze(this.paused || this.held);
  },

  togglePause() {
    this.paused = !this.paused;
    const button = this.el.querySelector("[data-pause]");
    button.setAttribute("aria-pressed", this.paused);
    button.querySelector("[data-icon-pause]").hidden = this.paused;
    button.querySelector("[data-icon-play]").hidden = !this.paused;
    this.sound.freeze(this.paused || this.held);
  },

  toggleMute() {
    this.muted = !this.muted;
    mute(this.muted);
    const button = this.el.querySelector("[data-mute]");
    button.setAttribute("aria-pressed", this.muted);
    button.querySelector("[data-icon-sound]").hidden = this.muted;
    button.querySelector("[data-icon-muted]").hidden = !this.muted;
  },

  share(button) {
    const url = this.el.dataset.shareUrl;
    const done = () => this.pushEvent("shared", {});

    if (navigator.share) {
      navigator.share({ url, title: document.title }).then(done).catch(() => {});
    } else {
      navigator.clipboard.writeText(url).then(() => {
        const label = button.textContent;
        button.textContent = button.dataset.copied;
        setTimeout(() => (button.textContent = label), 2000);
        done();
      });
    }
  },
};
