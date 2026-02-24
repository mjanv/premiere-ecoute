defmodule PremiereEcoute.Radio.Workers.LinkProviderTrack do
  @moduledoc """
  Oban worker that resolves missing provider IDs for radio tracks.

  Given a radio track with at least one known provider ID (e.g. Spotify), fetches track metadata and searches the other provider (e.g. Deezer) to find the equivalent track ID. Updates the radio track's provider_ids map.
  """

  use PremiereEcouteCore.Worker, queue: :radio, max_attempts: 3

  require Logger

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Radio

  @providers [:spotify, :deezer]

  @impl true
  def perform(%Oban.Job{args: %{"radio_track_id" => id, "provider" => provider}}) do
    case Radio.get_track(id) do
      nil ->
        Logger.warning("[#{__MODULE__}] radio track #{id} not found")
        :ok

      track ->
        @providers
        |> Enum.reject(fn p -> p == String.to_atom(provider) or p in Map.keys(track.provider_ids) end)
        |> Enum.reduce_while(:ok, fn target, :ok -> resolve(track, target) end)
    end
  end

  defp resolve(track, target) do
    with {:ok, [result | _]} <- Apis.provider(target).search_tracks(query: "#{track.artist} #{track.name}"),
         {:ok, _} <- Radio.add_provider(track, %{target => result.track_id}) do
      {:cont, :ok}
    else
      {:ok, []} ->
        Logger.debug("[#{__MODULE__}] no #{target} match for track #{track.id}")
        {:cont, :ok}

      {:error, reason} ->
        Logger.warning("[#{__MODULE__}] failed to resolve #{target} ID for track #{track.id}: #{inspect(reason)}")
        {:halt, {:error, reason}}
    end
  end
end
