defmodule PremiereEcoute.Playlists.Services.PlaylistNotification do
  @moduledoc """
  Notifies playlist subscribers by enqueuing delivery jobs per channel.
  """

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Notifications
  alias PremiereEcoute.Notifications.Types.PlaylistUpdated
  alias PremiereEcoute.Playlists.PlaylistSubscription
  alias PremiereEcoute.Playlists.Services.PlaylistEmail

  @spec notify(LibraryPlaylist.t()) :: {:ok, non_neg_integer()}
  def notify(%LibraryPlaylist{} = playlist) do
    {:ok, email_jobs} = notify_email(playlist)
    in_app_count = notify_in_app(playlist)
    {:ok, length(email_jobs) + in_app_count}
  end

  defp notify_email(%LibraryPlaylist{} = playlist) do
    subscribers = PlaylistSubscription.list_subscribers(playlist, :email)
    PlaylistEmail.email(playlist, subscribers)
  end

  defp notify_in_app(%LibraryPlaylist{title: title, url: url} = playlist) do
    notification = %PlaylistUpdated{playlist_title: title, playlist_url: url}

    playlist
    |> PlaylistSubscription.list_subscribers(:notification)
    |> Enum.count(fn user ->
      match?({:ok, _}, Notifications.dispatch(user, notification))
    end)
  end
end
