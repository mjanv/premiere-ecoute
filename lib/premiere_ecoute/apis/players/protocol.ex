defmodule PremiereEcoute.Apis.Players.Protocol do
  @moduledoc """
  Wire protocol of the desktop player (version 1).

  Pure functions that validate incoming payloads and convert them to internal terms. Event names and JSON shapes are known here and in `PremiereEcouteWeb.Player.Channel` only. See `docs/plans/local-player.md`.
  """

  alias PremiereEcoute.Apis.Players.PlaybackState

  @max_string 512
  @max_genres 10
  @acks %{
    "ok" => :ok,
    "error" => :error,
    "rejected" => :rejected,
    "expired" => :expired,
    "duplicate" => :duplicate
  }
  @playbacks %{"playing" => :playing, "paused" => :paused, "stopped" => :stopped}
  @repeats %{"none" => :none, "track" => :track, "list" => :list}

  @type snapshot :: %{
          running: boolean(),
          playback: :playing | :paused | :stopped,
          uri: String.t() | nil,
          title: String.t(),
          artist: String.t(),
          album: String.t(),
          album_artist: String.t(),
          track_number: pos_integer() | nil,
          album_track_count: pos_integer() | nil,
          genres: [String.t()],
          shuffle: boolean() | nil,
          repeat: :none | :track | :list | nil,
          position_ms: non_neg_integer(),
          length_ms: non_neg_integer(),
          volume: float() | nil
        }

  @doc "Validates a `snapshot` payload."
  @spec snapshot(map()) :: {:ok, pos_integer(), snapshot()} | {:error, :invalid}
  def snapshot(%{"seq" => seq, "snapshot" => %{} = snapshot}) when is_integer(seq) and seq >= 0 do
    with %{"running" => running, "playback" => playback} when is_boolean(running) <- snapshot,
         {:ok, playback} <- Map.fetch(@playbacks, playback),
         {:ok, position_ms} <- non_neg_integer(snapshot["position_ms"]),
         {:ok, length_ms} <- non_neg_integer(snapshot["length_ms"]),
         {:ok, volume} <- volume(snapshot["volume"]) do
      {:ok, seq,
       %{
         running: running,
         playback: playback,
         uri: string(snapshot["uri"], nil),
         title: string(snapshot["title"], ""),
         artist: string(snapshot["artist"], ""),
         album: string(snapshot["album"], ""),
         album_artist: string(snapshot["album_artist"], ""),
         track_number: positive_integer(snapshot["track_number"]),
         album_track_count: positive_integer(snapshot["album_track_count"]),
         genres: genres(snapshot["genres"]),
         shuffle: boolean(snapshot["shuffle"]),
         repeat: Map.get(@repeats, snapshot["repeat"]),
         position_ms: position_ms,
         length_ms: length_ms,
         volume: volume
       }}
    else
      _ -> {:error, :invalid}
    end
  end

  def snapshot(_payload), do: {:error, :invalid}

  @doc """
  Converts a validated snapshot to the playback state the rest of the application reads.

  Reads the album fields with a default, so a snapshot without them gives the same state as before they existed.
  """
  @spec playback_state(snapshot()) :: PlaybackState.t()
  def playback_state(snapshot) do
    %PlaybackState{
      is_playing: snapshot.playback == :playing,
      progress_ms: snapshot.position_ms,
      device: if(snapshot.running, do: %{name: "Desktop", is_active: true}),
      item: item(snapshot),
      status: :normal
    }
  end

  defp item(%{uri: nil}), do: PlaybackState.default().item

  defp item(snapshot) do
    %{
      uri: snapshot.uri,
      name: snapshot.title,
      duration_ms: max(snapshot.length_ms, 1),
      artists: [%{name: snapshot.artist}],
      type: :album,
      track_number: Map.get(snapshot, :track_number),
      album: %{name: snapshot.album, total_tracks: Map.get(snapshot, :album_track_count) || 0, images: []}
    }
  end

  @doc "Validates an `ack` payload."
  @spec ack(map()) :: {:ok, String.t(), atom(), String.t() | nil} | {:error, :invalid}
  def ack(%{"command_id" => id, "status" => status} = payload) when is_binary(id) do
    case Map.fetch(@acks, status) do
      {:ok, status} -> {:ok, id, status, string(payload["error"], nil)}
      :error -> {:error, :invalid}
    end
  end

  def ack(_payload), do: {:error, :invalid}

  @doc "Encodes a command for the `command` event."
  @spec command(%{id: String.t(), type: atom(), args: map(), ttl_ms: pos_integer()}) :: map()
  def command(%{id: id, type: type, args: args, ttl_ms: ttl_ms}) do
    %{"id" => id, "type" => Atom.to_string(type), "args" => Map.new(args, fn {k, v} -> {to_string(k), v} end), "ttl_ms" => ttl_ms}
  end

  @doc "Encodes a `disconnect` reason."
  @spec disconnect(atom()) :: map()
  def disconnect(reason), do: %{"reason" => Atom.to_string(reason)}

  defp non_neg_integer(value) when is_integer(value) and value >= 0, do: {:ok, value}
  defp non_neg_integer(_value), do: :error

  # The extras are optional and never worth refusing a snapshot for: a wrong type is "unknown".
  defp positive_integer(value) when is_integer(value) and value > 0, do: value
  defp positive_integer(_value), do: nil

  defp boolean(value) when is_boolean(value), do: value
  defp boolean(_value), do: nil

  defp genres(values) when is_list(values) do
    values |> Enum.filter(&is_binary/1) |> Enum.take(@max_genres) |> Enum.map(&string(&1, ""))
  end

  defp genres(_values), do: []

  defp volume(nil), do: {:ok, nil}
  defp volume(value) when is_number(value) and value >= 0 and value <= 1, do: {:ok, value / 1}
  defp volume(_value), do: :error

  defp string(value, _default) when is_binary(value), do: String.slice(value, 0, @max_string)
  defp string(_value, default), do: default
end
