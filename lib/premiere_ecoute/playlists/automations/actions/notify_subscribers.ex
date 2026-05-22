defmodule PremiereEcoute.Playlists.Automations.Actions.NotifySubscribers do
  @moduledoc false

  use PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists

  action "notify_subscribers" do
    description("Notifies all subscribers across all channels (email, in-app).")

    inputs do
      input(:playlist, :playlist_id, required: true, description: "Playlist to notify subscribers about")
    end

    outputs do
      output(:notified_count, :integer, description: "Total notifications dispatched (email jobs + in-app)")
    end
  end

  @impl true
  def execute(%{"playlist" => playlist_id}, _context, scope) do
    case LibraryPlaylist.get_by_playlist_id(scope.user, playlist_id) do
      nil ->
        {:error, :playlist_not_found}

      playlist ->
        with {:ok, count} <- Playlists.notify_subscribers(playlist) do
          {:ok, %{"notified_count" => count}}
        end
    end
  end
end
