// AudioPlayer hook — a custom HTML5 audio player with play/pause, a seekable progress bar,
// and current/total time. Drives a hidden <audio> element so the UI can match the app's design.
//
// Expected markup (ids are relative lookups within the hook root):
//   <div id="player-<guid>" phx-hook="AudioPlayer" data-src="...">
//     <audio data-role="audio" preload="metadata" src="..."></audio>
//     <button data-role="toggle">…play/pause icons…</button>
//     <div data-role="bar"><div data-role="progress"></div></div>
//     <span data-role="current">0:00</span> / <span data-role="duration">0:00</span>
//   </div>

function fmt(seconds) {
  if (!isFinite(seconds) || seconds < 0) return "0:00";
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, "0")}`;
}

export const AudioPlayer = {
  mounted() {
    const root = this.el;
    const audio = root.querySelector('[data-role="audio"]');
    const toggle = root.querySelector('[data-role="toggle"]');
    const bar = root.querySelector('[data-role="bar"]');
    const progress = root.querySelector('[data-role="progress"]');
    const currentEl = root.querySelector('[data-role="current"]');
    const durationEl = root.querySelector('[data-role="duration"]');
    const playIcon = root.querySelector('[data-role="icon-play"]');
    const pauseIcon = root.querySelector('[data-role="icon-pause"]');

    this._audio = audio;

    const showPlay = (playing) => {
      if (playIcon) playIcon.classList.toggle("hidden", playing);
      if (pauseIcon) pauseIcon.classList.toggle("hidden", !playing);
    };

    const render = () => {
      const ratio = audio.duration ? audio.currentTime / audio.duration : 0;
      if (progress) progress.style.width = `${ratio * 100}%`;
      if (currentEl) currentEl.textContent = fmt(audio.currentTime);
    };

    this._onLoaded = () => {
      if (durationEl) durationEl.textContent = fmt(audio.duration);
    };
    this._onTime = render;
    this._onPlay = () => showPlay(true);
    this._onPause = () => showPlay(false);
    this._onEnded = () => {
      showPlay(false);
      if (progress) progress.style.width = "0%";
    };

    audio.addEventListener("loadedmetadata", this._onLoaded);
    audio.addEventListener("timeupdate", this._onTime);
    audio.addEventListener("play", this._onPlay);
    audio.addEventListener("pause", this._onPause);
    audio.addEventListener("ended", this._onEnded);

    this._onToggle = () => {
      if (audio.paused) audio.play().catch(() => {});
      else audio.pause();
    };
    if (toggle) toggle.addEventListener("click", this._onToggle);

    // Click/drag anywhere on the bar to seek.
    this._onSeek = (event) => {
      const rect = bar.getBoundingClientRect();
      const ratio = Math.min(1, Math.max(0, (event.clientX - rect.left) / rect.width));
      if (audio.duration) audio.currentTime = ratio * audio.duration;
    };
    if (bar) bar.addEventListener("click", this._onSeek);
  },

  destroyed() {
    const audio = this._audio;
    if (audio) {
      audio.pause();
      audio.removeEventListener("loadedmetadata", this._onLoaded);
      audio.removeEventListener("timeupdate", this._onTime);
      audio.removeEventListener("play", this._onPlay);
      audio.removeEventListener("pause", this._onPause);
      audio.removeEventListener("ended", this._onEnded);
    }
  },
};
