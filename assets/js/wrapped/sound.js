import { Howl, Howler } from "howler";

// Sound of a Wrapped, shared by every render: the 30 s preview playing behind the cards.

const VOLUME = 0.55;

// One preview at a time. A Howl can play several overlapping instances of itself, so every call
// targets the single instance id started here; an outgoing preview only lives for its fade-out.
export class Sound {
  constructor() {
    this.url = null;
    this.howl = null;
    this.id = null;
    this.frozen = false;
  }

  // Crossfades to a preview; keeps playing when the next card has the same one or none.
  play(url) {
    if (!url || url === this.url) return;

    this.fadeOut();
    this.url = url;
    this.howl = new Howl({ src: [url], format: ["mp3"], html5: true, loop: true, volume: 0 });
    this.id = null;
    if (!this.frozen) this.start();
  }

  start() {
    this.id = this.howl.play();
    this.howl.fade(0, VOLUME, 1500, this.id);
  }

  fadeOut() {
    const old = this.howl;
    const id = this.id;
    this.howl = null;
    this.url = null;
    this.id = null;
    if (!old) return;

    // A paused or never-started preview has nothing to fade
    if (id === null || !old.playing(id)) return old.unload();

    // Fast navigation: never more than one preview fading out
    this.outgoing?.unload();
    this.outgoing = old;
    old.fade(old.volume(id), 0, 1200, id);
    setTimeout(() => {
      old.unload();
      if (this.outgoing === old) this.outgoing = null;
    }, 1300);
  }

  freeze(frozen) {
    this.frozen = frozen;
    if (!this.howl) return;

    if (frozen) {
      if (this.id !== null) this.howl.pause(this.id);
    } else if (this.id === null) {
      this.start();
    } else if (!this.howl.playing(this.id)) {
      this.howl.play(this.id);
    }
  }

  destroy() {
    this.howl?.unload();
    this.outgoing?.unload();
  }
}

// Mutes or unmutes every preview at once
export const mute = (muted) => Howler.mute(muted);
