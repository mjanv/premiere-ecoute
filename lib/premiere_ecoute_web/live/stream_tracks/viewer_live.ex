defmodule PremiereEcouteWeb.StreamTracks.ViewerLive do
  @moduledoc """
  Public LiveView for viewing daily stream tracks.

  Displays tracks played by a streamer on a specific date with real-time updates.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.StreamTracks

  @impl true
  def mount(%{"username" => username, "date" => date_str}, _session, socket) do
    with {:ok, date} <- Date.from_iso8601(date_str),
         user when not is_nil(user) <- Accounts.get_user_by_twitch_id(username),
         true <- tracks_visible?(user) do
      tracks = StreamTracks.get_tracks(user.id, date)

      # Subscribe to real-time updates
      Phoenix.PubSub.subscribe(
        PremiereEcoute.PubSub,
        "stream_tracks:#{user.id}:#{Date.to_iso8601(date)}"
      )

      {:ok,
       assign(socket,
         user: user,
         date: date,
         tracks: tracks,
         page_title: "#{username}'s tracks - #{date}"
       )}
    else
      _ -> {:ok, push_navigate(socket, to: "/")}
    end
  end

  @impl true
  def handle_info({:track_added, track}, socket) do
    {:noreply, update(socket, :tracks, &(&1 ++ [track]))}
  end

  defp tracks_visible?(user) do
    case user.profile.stream_track_settings do
      %{visibility: :public} -> true
      _ -> false
    end
  end
end
