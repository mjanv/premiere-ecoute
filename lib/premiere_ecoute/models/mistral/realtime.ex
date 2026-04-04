defmodule PremiereEcoute.Models.Realtime do
  @moduledoc false

  use WebSockex

  require Logger

  @url "wss://api.mistral.ai/v1/audio/transcriptions/realtime"

  def start_link(_args) do
    WebSockex.start_link(@url, __MODULE__, %{initialized: false},
      extra_headers: [
        {"Authorization", "Bearer #{Application.get_env(:premiere_ecoute, :mistral)[:api_key]}"}
      ]
    )
  end

  @doc """
  Sends a chunk of audio.
  Expects raw binary audio (e.g., PCM 16-bit 24kHz).
  """
  def push_audio(pid, binary_audio) do
    payload = %{
      type: "input_audio_buffer.append",
      audio: Base.encode64(binary_audio)
    }

    WebSockex.cast(pid, {:send_event, payload})
  end

  # --- Server Callbacks ---

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("Connected to Mistral Realtime API")

    # Immediately initialize the session
    _init_event = %{
      type: "session.update",
      session: %{
        model: "voxtral-mini-transcribe-realtime-2602",
        # Transcriptions only
        modalities: ["text"]
        # Add other config like language here
      }
    }

    # {:text, Jason.encode!(init_event)

    {:ok, state}
  end

  @impl true
  def handle_cast({:send_event, payload}, state) do
    {:reply, {:text, Jason.encode!(payload)}, state}
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, %{"type" => "transcription.delta", "delta" => text}} ->
        # Partial transcript received
        IO.write(text)
        {:ok, state}

      {:ok, %{"type" => "transcription.completed", "transcript" => full_text}} ->
        # Final sentence/turn received
        IO.puts("\n[Final]: #{full_text}")
        {:ok, state}

      {:ok, event} ->
        Logger.debug("Received event: #{event["type"]}")
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  @impl true
  def handle_disconnect(conn_status, state) do
    Logger.error("Disconnected: #{inspect(conn_status)}")
    {:ok, state}
  end
end
