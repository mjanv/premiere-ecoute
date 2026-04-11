// PlaySound hook — plays an audio file when `data-play` attribute is present.
//
// Usage:
//   <div id="my-el" phx-hook="PlaySound" data-sound="/audio/ding.mp3" {if condition, do: %{"data-play" => true}, else: %{}} />
//
// The sound fires once when `data-play` transitions from absent to present.
// Removing `data-play` resets the state so it can fire again next time.

export const PlaySound = {
  mounted() {
    this.playing = this.el.hasAttribute("data-play");
    if (this.playing) this.play();
  },

  updated() {
    const shouldPlay = this.el.hasAttribute("data-play");
    if (shouldPlay && !this.playing) this.play();
    this.playing = shouldPlay;
  },

  play() {
    const src = this.el.dataset.sound;
    if (src) new Audio(src).play().catch(() => {});
  },
};
