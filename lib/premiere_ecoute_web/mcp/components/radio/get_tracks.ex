defmodule PremiereEcouteWeb.Mcp.Components.Radio.GetTracks do
  @moduledoc "List tracks played on a streamer's radio for a date or date range (public radios only)"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Radio

  schema do
    field :username, :string, required: true
    field :date_from, :string, description: "Start date in YYYY-MM-DD format. Defaults to today."
    field :date_to, :string, description: "End date in YYYY-MM-DD format. Defaults to date_from."
  end

  @impl true
  def execute(%{username: username} = params, frame) do
    with {:ok, date_from} <- parse_date(Map.get(params, :date_from)),
         {:ok, date_to} <- parse_date(Map.get(params, :date_to), date_from),
         :ok <- validate_range(date_from, date_to),
         user when not is_nil(user) <- User.get_by(username: username),
         :public <- radio_visibility(user) do
      tracks =
        Radio.get_tracks_range(user.id, date_from, date_to)
        |> Enum.map(&format/1)

      {:reply,
       Response.json(Response.tool(), %{
         date_from: Date.to_iso8601(date_from),
         date_to: Date.to_iso8601(date_to),
         tracks: tracks
       }), frame}
    else
      nil ->
        {:reply, Response.error(Response.tool(), "Streamer not found."), frame}

      :private ->
        {:reply, Response.error(Response.tool(), "This streamer's radio is private."), frame}

      {:error, :invalid_date} ->
        {:reply, Response.error(Response.tool(), "Invalid date format. Use YYYY-MM-DD."), frame}

      {:error, :invalid_range} ->
        {:reply, Response.error(Response.tool(), "date_from must be before or equal to date_to."), frame}
    end
  end

  defp parse_date(nil), do: {:ok, Date.utc_today()}

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, :invalid_date}
    end
  end

  defp parse_date(nil, default), do: {:ok, default}
  defp parse_date(date_str, _default), do: parse_date(date_str)

  defp validate_range(date_from, date_to) do
    if Date.compare(date_from, date_to) in [:lt, :eq], do: :ok, else: {:error, :invalid_range}
  end

  defp radio_visibility(%User{profile: %{radio_settings: %{visibility: :public}}}), do: :public
  defp radio_visibility(_), do: :private

  defp format(track) do
    %{
      id: track.id,
      name: track.name,
      artist: track.artist,
      album: track.album,
      duration_ms: track.duration_ms,
      started_at: track.started_at,
      spotify_id: track.provider_ids[:spotify] || track.provider_ids["spotify"]
    }
  end
end
