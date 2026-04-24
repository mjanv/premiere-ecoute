defmodule PremiereEcouteWeb.Radio.ViewerLive do
  @moduledoc """
  Public LiveView for viewing daily radio tracks.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Components.Navigation.DayNav

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Notifications
  alias PremiereEcoute.Notifications.Types.WantlistSave
  alias PremiereEcoute.Radio
  alias PremiereEcoute.Wantlists

  @impl true
  def mount(%{"username" => username} = params, _session, socket) do
    date =
      case params do
        %{"date" => date_str} ->
          case Date.from_iso8601(date_str) do
            {:ok, d} -> d
            _ -> nil
          end

        _ ->
          Date.utc_today()
      end

    with false <- is_nil(date),
         user when not is_nil(user) <- Accounts.get_user_by_username(username),
         :public <- Accounts.profile(user, [:radio_settings, :visibility]) do
      today = Date.utc_today()

      {:ok,
       assign(socket,
         user: user,
         date: date,
         tracks: [],
         today: today,
         oldest_date: Date.add(today, -Accounts.profile(user, [:radio_settings, :retention_days])),
         timezone: Accounts.profile(user, [:timezone], "UTC"),
         wantlisted_ids: MapSet.new()
       )}
    else
      _ -> {:ok, push_navigate(socket, to: "/")}
    end
  end

  @impl true
  def handle_params(%{"date" => date_str}, _uri, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        tracks = Radio.get_tracks(socket.assigns.user.id, date)
        {:noreply, assign(socket, date: date, tracks: tracks, wantlisted_ids: load_wantlisted_ids(socket, tracks))}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket) do
    date = Date.utc_today()
    tracks = Radio.get_tracks(socket.assigns.user.id, date)
    {:noreply, assign(socket, date: date, tracks: tracks, wantlisted_ids: load_wantlisted_ids(socket, tracks))}
  end

  @impl true
  def handle_event("add_track_to_wantlist", %{"spotify-id" => spotify_id}, socket) do
    current_scope = socket.assigns[:current_scope]

    if current_scope && current_scope.user do
      case Wantlists.add_radio_track(current_scope.user.id, spotify_id) do
        {:ok, _} ->
          {track_name, artist_name} = find_track_info(socket.assigns.tracks, spotify_id)
          Notifications.dispatch(current_scope.user, %WantlistSave{track_name: track_name, artist_name: artist_name})
          {:noreply, assign(socket, :wantlisted_ids, load_wantlisted_ids(socket, socket.assigns.tracks))}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  defp find_track_info(tracks, spotify_id) do
    case Enum.find(tracks, fn t -> t.provider_ids[:spotify] == spotify_id end) do
      %{name: name, artist: artist} -> {name, artist}
      _ -> {spotify_id, ""}
    end
  end

  defp load_wantlisted_ids(socket, tracks) do
    case socket.assigns[:current_scope] do
      %{user: %{id: user_id}} ->
        spotify_ids = tracks |> Enum.map(& &1.provider_ids[:spotify]) |> Enum.reject(&is_nil/1)
        Wantlists.wantlisted_spotify_ids(user_id, spotify_ids)

      _ ->
        MapSet.new()
    end
  end

  defp link(_track, :spotify, provider_id), do: "https://open.spotify.com/track/#{provider_id}"
  defp link(_track, :deezer, provider_id), do: "https://www.deezer.com/track/#{provider_id}"

  defp link(track, :apple, _provider_id),
    do: "https://music.apple.com/us/search?term=#{String.upcase(track.name)} #{String.upcase(track.artist)}"
end
