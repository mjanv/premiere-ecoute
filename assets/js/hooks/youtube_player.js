// YoutubePlayer hook — embeds the YouTube IFrame Player API for a session's clip.
// Fire-and-forget: no playback state is pushed back to the server. The streamer
// controls playback locally (native player controls) after adding this page as
// an OBS Browser Source. The root element uses phx-update="ignore" and is only
// ever rendered once per clip (a session's video never changes mid-session), so
// there is no update-in-place case to handle — a new video means a new element.

let apiLoadingPromise = null;

function loadIframeApi() {
  if (window.YT && window.YT.Player) return Promise.resolve();

  if (!apiLoadingPromise) {
    apiLoadingPromise = new Promise((resolve) => {
      const previous = window.onYouTubeIframeAPIReady;
      window.onYouTubeIframeAPIReady = () => {
        if (previous) previous();
        resolve();
      };

      const tag = document.createElement("script");
      tag.src = "https://www.youtube.com/iframe_api";
      document.head.appendChild(tag);
    });
  }

  return apiLoadingPromise;
}

// Commands pushed from the dashboard's control panel, relayed here via
// ClipOverlayLive's {:clip_command, ...} PubSub -> push_event("clip_command", ...).
function applyClipCommand(player, { command, value }) {
  switch (command) {
    case "play":
      player.playVideo();
      break;
    case "pause":
      player.pauseVideo();
      break;
    case "volume":
      player.setVolume(value);
      break;
    case "seek":
      player.seekTo(value, true);
      break;
  }
}

const PROGRESS_INTERVAL_MS = 1000;

export const YoutubePlayer = {
  mounted() {
    this._videoId = this.el.dataset.videoId;

    this.handleEvent("clip_command", (payload) => {
      if (this._player) applyClipCommand(this._player, payload);
    });

    loadIframeApi().then(() => {
      if (!this._videoId) return;

      // Browsers block autoplay-with-sound without prior user interaction, which
      // an OBS Browser Source never provides. Start muted (always allowed) and
      // unmute immediately once playback actually begins — programmatic
      // mute/unmute after the fact is unrestricted, only the initial play call
      // is gated.
      this._player = new window.YT.Player(this.el, {
        videoId: this._videoId,
        width: "100%",
        height: "100%",
        playerVars: { autoplay: 1, mute: 1 },
        events: {
          onReady: (event) => {
            event.target.playVideo();
            this._startProgressReporting();
          },
          onStateChange: (event) => {
            if (event.data === window.YT.PlayerState.PLAYING) {
              event.target.unMute();
            }
            this._reportProgress();
          },
        },
      });
    });
  },

  // Pushed up to ClipOverlayLive, which relays it to the dashboard over PubSub
  // so the streamer's remote-control panel can show current time / duration
  // and reflect actual play/pause state on its buttons.
  _startProgressReporting() {
    this._progressInterval = setInterval(() => this._reportProgress(), PROGRESS_INTERVAL_MS);
  },

  _reportProgress() {
    if (!this._player || !this._player.getCurrentTime) return;

    this.pushEvent("clip_progress", {
      current_time: this._player.getCurrentTime(),
      duration: this._player.getDuration(),
      playing: this._player.getPlayerState() === window.YT.PlayerState.PLAYING,
    });
  },

  destroyed() {
    if (this._progressInterval) clearInterval(this._progressInterval);
    if (this._player && this._player.destroy) this._player.destroy();
  },
};
