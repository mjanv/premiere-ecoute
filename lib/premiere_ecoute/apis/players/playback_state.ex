defmodule PremiereEcoute.Apis.Players.PlaybackState do
  @moduledoc """
  Caches playback state for Spotify.

  Stores playback state with a configurable TTL per user (broadcaster).
  """

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcouteCore.Cache

  @cache :playback
  @ttl 10_000

  @doc """
  Gets playback state from cache or fetches fresh if expired/missing.
  """
  @spec get_playback_state(Scope.t(), map()) :: {:ok, map()} | {:error, term()}
  def get_playback_state(%Scope{user: %{id: user_id}} = scope, old_state) do
    with {:ok, nil} <- Cache.get(@cache, user_id),
         {:ok, state} <- Apis.spotify().get_playback_state(scope, %{}),
         _ <- Cache.put(@cache, user_id, state, expire: @ttl) do
      {:ok, state}
    else
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:error, reason}
      _ -> {:ok, old_state}
    end
  end
end
