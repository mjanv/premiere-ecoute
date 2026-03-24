defmodule PremiereEcouteWeb.Audio.AudioLive do
  @moduledoc """
  Dev-only LiveView for audio recording and speech-to-text transcription.

  Records audio chunks from the browser microphone, displays a live waveform,
  and transcribes speech using the local Whisper model via Bumblebee.
  """

  use PremiereEcouteWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, recording: false, chunks_received: 0, segments: [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 flex flex-col items-center justify-center gap-8 p-8">
      <h1 class="text-2xl font-semibold text-white tracking-tight">Audio recorder</h1>

      <canvas
        id="waveform"
        phx-hook="Microphone"
        phx-update="ignore"
        data-endianness={System.endianness()}
        class="rounded-xl border border-gray-800 block"
      >
      </canvas>

      <%!-- Record button --%>
      <button
        type="button"
        id="record-btn"
        phx-click={JS.dispatch("microphone:toggle", to: "#waveform")}
        class={[
          "flex items-center gap-2 px-6 py-3 rounded-full font-medium transition-all duration-200",
          if(@recording,
            do: "bg-red-500 hover:bg-red-600 text-white ring-4 ring-red-500/30",
            else: "bg-indigo-600 hover:bg-indigo-700 text-white"
          )
        ]}
      >
        <%= if @recording do %>
          <span class="w-3 h-3 rounded-sm bg-white animate-pulse"></span> Stop recording
        <% else %>
          <span class="w-3 h-3 rounded-full bg-white"></span> Record
        <% end %>
      </button>

      <%!-- Speech segments --%>
      <div class="w-full max-w-xl">
        <div class="flex items-center justify-between mb-2">
          <span class="text-xs font-medium text-gray-500 uppercase tracking-widest">Segments</span>
          <span class="text-xs text-gray-600">{length(@segments)} detected</span>
        </div>
        <div class="rounded-xl bg-gray-900 border border-gray-800 p-4 min-h-[80px] max-h-64 overflow-y-auto space-y-1">
          <div :if={@segments == []} class="text-gray-600 text-sm">No segments yet.</div>
          <div
            :for={{seg, i} <- Enum.with_index(@segments)}
            class="flex items-center gap-3 text-sm font-mono"
          >
            <span class="text-gray-500">{i + 1}</span>
            <span class={["w-2 h-2 rounded-full shrink-0", if(seg.is_clean, do: "bg-green-500", else: "bg-yellow-500")]}></span>
            <span class="text-white">
              {format_ms(seg.start_ms)} – {format_ms(seg.end_ms)}
            </span>
            <span class="text-gray-500 text-xs">
              {seg.end_ms - seg.start_ms}ms
            </span>
            <span class={[
              "text-xs px-1.5 py-0.5 rounded",
              if(seg.is_clean, do: "bg-green-900 text-green-400", else: "bg-yellow-900 text-yellow-400")
            ]}>
              {if seg.is_clean, do: "speech", else: "noisy"}
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_ms(ms) do
    s = div(ms, 1000)
    m = div(s, 60)
    :io_lib.format("~2..0B:~2..0B.~3..0B", [m, rem(s, 60), rem(ms, 1000)])
  end

  @impl true
  def handle_event("recording_started", _params, socket) do
    {:noreply, assign(socket, recording: true, chunks_received: 0, segments: [])}
  end

  @impl true
  def handle_event("recording_stopped", _params, socket) do
    {:noreply, assign(socket, :recording, false)}
  end

  @impl true
  def handle_event("audio_chunk", _params, socket) do
    {:noreply, update(socket, :chunks_received, &(&1 + 1))}
  end

  @impl true
  def handle_event("segment_detected", %{"start_ms" => start_ms, "end_ms" => end_ms, "is_clean" => is_clean}, socket) do
    segment = %{start_ms: round(start_ms), end_ms: round(end_ms), is_clean: is_clean}
    {:noreply, update(socket, :segments, &(&1 ++ [segment]))}
  end
end
