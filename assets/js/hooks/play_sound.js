// PlaySound hook — plays an audio file when the server sends a "play_sound" event.
//
// Usage:
//   <span id="my-el" phx-hook="PlaySound" data-sound="/audio/ding.mp3" />
//   Server: push_event(socket, "play_sound", %{})

export const PlaySound = {
  mounted() {
    this.handleEvent("play_sound", () => {
      const src = this.el.dataset.sound;
      if (src) new Audio(src).play().catch(() => {});
    });
  },
};
