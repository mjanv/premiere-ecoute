defmodule PremiereEcouteWeb.Podcasts.Components do
  @moduledoc """
  Shared podcast UI components.
  """

  use PremiereEcouteWeb, :html

  @doc """
  A custom HTML5 audio player (play/pause, seekable progress bar, time) driven by the
  `AudioPlayer` JS hook. `src` is the audio enclosure URL; `id` must be unique on the page.
  """
  attr :id, :string, required: true
  attr :src, :string, required: true

  def audio_player(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="AudioPlayer"
      class="flex items-center gap-3 rounded-xl bg-white/5 border border-white/10 p-3"
    >
      <audio data-role="audio" preload="metadata" src={@src}></audio>

      <button
        type="button"
        data-role="toggle"
        class="flex-shrink-0 w-11 h-11 rounded-full bg-purple-600 hover:bg-purple-700 text-white flex items-center justify-center transition-colors"
        aria-label="Play / pause"
      >
        <svg data-role="icon-play" class="w-5 h-5 ml-0.5" fill="currentColor" viewBox="0 0 20 20">
          <path d="M6 4l10 6-10 6V4z" />
        </svg>
        <svg data-role="icon-pause" class="w-5 h-5 hidden" fill="currentColor" viewBox="0 0 20 20">
          <path d="M6 4h3v12H6V4zm5 0h3v12h-3V4z" />
        </svg>
      </button>

      <div class="flex-1 min-w-0">
        <div data-role="bar" class="h-2 rounded-full bg-white/10 cursor-pointer overflow-hidden">
          <div data-role="progress" class="h-full w-0 bg-purple-500 rounded-full"></div>
        </div>
        <div class="mt-1 flex justify-between text-xs text-gray-400 tabular-nums">
          <span data-role="current">0:00</span>
          <span data-role="duration">0:00</span>
        </div>
      </div>
    </div>
    """
  end
end
