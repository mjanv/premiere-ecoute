import { animate } from "motion";
import { Sound, mute } from "../../sound";
import { Background, palette } from "./background";
import { enter } from "./cards";
import { CARD_MS, HOLD_MS, SWIPE_PX, reducedMotion } from "./config";

// Classic render of a Wrapped. The server renders every card once; this hook
// runs the whole playback in the browser: navigation, auto-advance, pause,
// shader background and sound. The entrance of each card lives in ./cards.

export const WrappedPlayer = {
  mounted() {
    const el = this.el;

    this.cards = [...el.querySelectorAll("[data-card]")];
    this.bars = [...el.querySelectorAll("[data-progress]")];
    this.start = el.querySelector("[data-start]");
    this.index = -1;
    this.elapsed = 0;
    this.paused = false;
    this.animations = [];
    this.exits = new Map();
    this.reduced = reducedMotion();
    this.sound = new Sound();
    this.hasSound = false;
    this.begun = false;

    // Preview URLs arrive once the page is live: they are signed, short-lived and never rendered
    this.handleEvent("wrapped:previews", ({ urls }) => {
      this.cards.forEach((card, i) => urls[i] && (card.dataset.preview = urls[i]));
      this.hasSound = urls.some(Boolean);
      if (!this.begun) return;

      this.el.querySelector("[data-mute]").hidden = !this.hasSound;
      // Play the latest preview at or before the current card
      const url = this.cards.slice(0, this.index + 1).map((card) => card.dataset.preview).filter(Boolean).pop();
      this.sound.play(url);
    });

    if (!this.reduced) {
      try {
        this.background = new Background(el.querySelector("[data-bg]"));
      } catch (_error) {
        // No WebGL: the CSS gradient of .wrapped stays visible
      }
    }
    this.tint(this.cards[0]);

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

    this.tick = (now) => {
      this.raf = requestAnimationFrame(this.tick);
      const delta = now - (this.last || now);
      this.last = now;
      if (this.index < 0 || this.paused || this.held || document.hidden) return;

      this.elapsed = Math.min(this.elapsed + delta, CARD_MS);
      this.bars[this.index].style.transform = `scaleX(${this.elapsed / CARD_MS})`;
      if (this.elapsed >= CARD_MS && this.index < this.cards.length - 1) this.show(this.index + 1);
    };
  },

  destroyed() {
    cancelAnimationFrame(this.raf);
    window.removeEventListener("keydown", this.onKey);
    document.removeEventListener("visibilitychange", this.onVisibility);
    this.stopAnimations();
    this.background?.destroy();
    this.sound.destroy();
  },

  on(target, event, handler) {
    target?.addEventListener(event, handler);
  },

  begin() {
    this.begun = true;

    for (const selector of ["[data-pause]", "[data-prev]", "[data-next]"]) this.el.querySelector(selector).hidden = false;
    this.el.querySelector("[data-mute]").hidden = !this.hasSound;
    // Without auto-advance there is nothing to pause
    if (this.reduced) this.el.querySelector("[data-pause]").hidden = true;

    this.pushEvent("started", {});
    this.show(0);
    if (!this.reduced) this.raf = requestAnimationFrame(this.tick);
  },

  go(step) {
    const next = this.index + step;
    if (next < 0) return this.show(0);
    if (next >= this.cards.length) return;
    this.show(next);
  },

  show(index) {
    const previous = this.index < 0 ? this.start : this.cards[this.index];
    const card = this.cards[index];

    this.stopAnimations();
    this.index = index;
    this.elapsed = 0;
    this.bars.forEach((bar, i) => (bar.style.transform = `scaleX(${i < index ? 1 : 0})`));

    if (previous !== card) this.leave(previous);
    this.exits.get(card)?.cancel();
    this.exits.delete(card);
    card.style.opacity = "";
    card.style.transform = "";
    card.classList.add("is-active");
    card.removeAttribute("aria-hidden");

    this.tint(card);
    this.background?.kick();
    if (this.paused) this.togglePause();
    this.sound.play(card.dataset.preview);
    if (!this.reduced) this.animations = enter(card);
  },

  // The outgoing card rushes towards the viewer and fades while the next one lands
  leave(card) {
    const done = () => {
      this.exits.delete(card);
      card.style.opacity = "";
      card.style.transform = "";
      if (this.cards[this.index] === card) return;
      card.classList.remove("is-active");
      card.setAttribute("aria-hidden", "true");
    };

    if (this.reduced) return done();

    const exit = animate(card, { opacity: [1, 0], scale: [1, 1.12] }, { duration: 0.3, ease: [0.4, 0, 1, 1] });
    this.exits.set(card, exit);
    exit.then(() => this.exits.get(card) === exit && done());
  },

  tint(card) {
    const colors = palette(JSON.parse(card?.dataset.colors || "[]"));
    colors.forEach((color, i) => this.el.style.setProperty(`--c${i + 1}`, color));
    this.background?.tint(colors);
  },

  // Finishes running animations so that no element stays half-way or keeps a stale counter
  stopAnimations() {
    this.animations.forEach((animation) => animation.complete());
    this.animations = [];
  },

  press(event) {
    this.pressX = event.clientX;
    this.pressAt = performance.now();
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
    this.freeze();
  },

  togglePause() {
    this.paused = !this.paused;
    const button = this.el.querySelector("[data-pause]");
    button.setAttribute("aria-pressed", this.paused);
    button.querySelector("[data-icon-pause]").hidden = this.paused;
    button.querySelector("[data-icon-play]").hidden = !this.paused;
    this.freeze();
  },

  freeze() {
    const frozen = this.paused || this.held;
    this.animations.forEach((animation) => (frozen ? animation.pause() : animation.play()));
    this.sound.freeze(frozen);
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
