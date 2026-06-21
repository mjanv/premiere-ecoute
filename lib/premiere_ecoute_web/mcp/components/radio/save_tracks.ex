defmodule PremiereEcouteWeb.Mcp.Components.Radio.SaveTracks do
  @moduledoc "Save tracks from a streamer's radio to the authenticated user's wantlist, filtered by spotify_id, track name, or artist"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Radio
  alias PremiereEcoute.Wantlists

  schema do
    field :username, :string, required: true
    field :date, :string, description: "Date in YYYY-MM-DD format. Defaults to today."
    field :spotify_id, :string
    field :track_name, :string
    field :artist_name, :string
  end

  @impl true
  def execute(params, %{assigns: %{current_user: user}} = frame) do
    with {:ok, date} <- parse_date(Map.get(params, :date)),
         broadcaster when not is_nil(broadcaster) <- User.get_by(username: params.username),
         :public <- radio_visibility(broadcaster) do
      tracks = Radio.get_tracks(broadcaster.id, date, build_filters(params))

      case tracks do
        [] ->
          {:reply, Response.error(Response.tool(), "No matching tracks found."), frame}

        tracks ->
          results = Enum.map(tracks, &save_track(user.id, &1))
          saved = Enum.count(results, &match?({:ok, _}, &1))
          failed = Enum.count(results, &match?({:error, _}, &1))

          msg =
            cond do
              failed == 0 -> "Saved #{saved} track(s) to wantlist (#{Date.to_iso8601(date)})."
              saved == 0 -> "Failed to save #{failed} track(s) (#{Date.to_iso8601(date)})."
              true -> "Saved #{saved} track(s), #{failed} failed (#{Date.to_iso8601(date)})."
            end

          {:reply, Response.text(Response.tool(), msg), frame}
      end
    else
      nil -> {:reply, Response.error(Response.tool(), "Streamer not found."), frame}
      :private -> {:reply, Response.error(Response.tool(), "This streamer's radio is private."), frame}
      {:error, :invalid_date} -> {:reply, Response.error(Response.tool(), "Invalid date format. Use YYYY-MM-DD."), frame}
    end
  end

  defp build_filters(params) do
    [
      name: nilify(Map.get(params, :track_name)),
      artist: nilify(Map.get(params, :artist_name)),
      spotify_id: nilify(Map.get(params, :spotify_id))
    ]
  end

  defp nilify(v) when is_binary(v) and v != "", do: v
  defp nilify(_), do: nil

  defp save_track(user_id, track) do
    case track.provider_ids[:spotify] || track.provider_ids["spotify"] do
      nil -> {:error, :no_spotify_id}
      spotify_id -> Wantlists.impl().add_radio_track(user_id, spotify_id)
    end
  end

  defp parse_date(nil), do: {:ok, Date.utc_today()}

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, :invalid_date}
    end
  end

  defp radio_visibility(%User{profile: %{radio_settings: %{visibility: :public}}}), do: :public
  defp radio_visibility(_), do: :private
end
