defmodule PremiereEcoute.Apis.Players.PlaybackState do
  @moduledoc """
  Typed representation of Spotify playback state.

  Caches playback state for Spotify with a configurable TTL per user (broadcaster).
  """

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcouteCore.Cache

  @cache :playback
  @default_ttl 60_000

  defstruct [:is_playing, :progress_ms, :device, :item]

  @type device :: %{name: String.t(), is_active: boolean()}
  @type item :: %{
          uri: String.t(),
          name: String.t(),
          duration_ms: pos_integer(),
          artists: [%{name: String.t()}],
          type: :album | :single
        }

  @type t :: %__MODULE__{
          is_playing: boolean(),
          progress_ms: non_neg_integer(),
          device: device() | nil,
          item: item() | nil
        }

  @doc "Converts raw Spotify API JSON map to a PlaybackState struct."
  @spec from_json(map()) :: t()
  def from_json(json) do
    %__MODULE__{
      is_playing: json["is_playing"],
      progress_ms: json["progress_ms"],
      device: convert_device(json["device"]),
      item: convert_item(json["item"])
    }
  end

  @doc """
  Gets playback state from cache or fetches fresh if expired/missing.
  """
  @spec get_playback_state(Scope.t(), map()) :: {:ok, map()} | {:error, term()}
  def get_playback_state(%Scope{user: %{id: user_id}} = scope, old_state) do
    with {:ok, nil} <- Cache.get(@cache, user_id),
         {:ok, state} <- Apis.spotify().get_playback_state(scope, %{}),
         _ <- Cache.put(@cache, user_id, state, expire: ttl(state)) do
      {:ok, state}
    else
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:error, reason}
      _ -> {:ok, old_state}
    end
  end

  defp convert_device(nil), do: nil
  defp convert_device(%{"name" => name, "is_active" => is_active}), do: %{name: name, is_active: is_active}

  defp convert_item(nil), do: nil

  defp convert_item(item) do
    %{
      uri: item["uri"],
      name: item["name"],
      duration_ms: item["duration_ms"],
      artists: Enum.map(item["artists"] || [], fn a -> %{name: a["name"]} end),
      type: item |> get_in(["album", "album_type"]) |> parse_type()
    }
  end

  defp parse_type("single"), do: :single
  defp parse_type(_), do: :album

  defp ttl(%{"item" => %{"duration_ms" => duration_ms}, "progress_ms" => progress_ms})
       when is_integer(duration_ms) and is_integer(progress_ms) do
    min(duration_ms - progress_ms, @default_ttl)
  end

  defp ttl(_), do: @default_ttl
end
