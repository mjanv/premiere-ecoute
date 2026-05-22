defmodule PremiereEcoute.Playlists.Services.PlaylistEmail do
  @moduledoc """
  Enqueues playlist email jobs for one user or a list of users.
  """

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.Workers.PlaylistEmailWorker

  @spec email(LibraryPlaylist.t(), User.t() | [User.t()]) :: {:ok, list()}
  def email(playlist, %User{} = user), do: email(playlist, [user])
  def email(%LibraryPlaylist{}, []), do: {:ok, []}

  def email(%LibraryPlaylist{id: playlist_id}, users) do
    users
    |> Enum.map(&%{"playlist_id" => playlist_id, "user_id" => &1.id})
    |> PlaylistEmailWorker.start()
  end
end
