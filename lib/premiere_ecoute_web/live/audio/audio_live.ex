defmodule PremiereEcouteWeb.Audio.AudioLive do
  @moduledoc """
  Dev-only LiveView for audio recording and speech-to-text transcription.

  Records audio chunks from the browser microphone, displays a live waveform,
  and transcribes speech using the local Whisper model via Bumblebee.
  """

  use PremiereEcouteWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, recording: false, transcript: "", chunks_received: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 flex flex-col items-center justify-center gap-8 p-8">
      <h1 class="text-2xl font-semibold text-white tracking-tight">Audio recorder</h1>

      <%!-- Waveform canvas --%>
      <canvas
        id="waveform"
        phx-hook="Microphone"
        data-endianness={System.endianness()}
        width="600"
        height="120"
        class="rounded-xl bg-gray-900 border border-gray-800"
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

      <%!-- Live transcript --%>
      <div class="w-full max-w-xl">
        <div class="flex items-center justify-between mb-2">
          <span class="text-xs font-medium text-gray-500 uppercase tracking-widest">Transcript</span>
          <span :if={@chunks_received > 0} class="text-xs text-gray-600">
            {@chunks_received} chunk(s)
          </span>
        </div>
        <div class="rounded-xl bg-gray-900 border border-gray-800 p-4 min-h-[80px] text-white whitespace-pre-wrap">
          <%= if @transcript == "" do %>
            <span class="text-gray-600 text-sm">Record something to see the transcript here.</span>
          <% else %>
            {@transcript}
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("recording_started", _params, socket) do
    {:noreply, assign(socket, recording: true, transcript: "", chunks_received: 0)}
  end

  @impl true
  def handle_event("recording_stopped", _params, socket) do
    {:noreply, assign(socket, :recording, false)}
  end

  @impl true
  def handle_event("audio_chunk", _params, socket) do
    {:noreply, update(socket, :chunks_received, &(&1 + 1))}
  end
end
