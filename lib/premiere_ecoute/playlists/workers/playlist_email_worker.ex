defmodule PremiereEcoute.Playlists.Workers.PlaylistEmailWorker do
  @moduledoc """
  Sends a playlist email to a single recipient.
  """

  use PremiereEcouteCore.Worker, queue: :emails, max_attempts: 10

  import Swoosh.Email

  alias PremiereEcoute.Accounts.Mailer
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.Formatters.Formatter
  alias PremiereEcoute.Playlists.Formatters.HtmlEmail
  alias PremiereEcoute.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"playlist_id" => playlist_id, "user_id" => user_id}}) do
    with %LibraryPlaylist{} = playlist <- Repo.get(LibraryPlaylist, playlist_id),
         %User{email: email} <- User.get!(user_id),
         {:ok, live_playlist} <- Apis.provider(playlist.provider).get_playlist(playlist.playlist_id),
         {:ok, html} <-
           Formatter.format(
             %HtmlEmail{
               tracks: live_playlist.tracks,
               track_count: length(live_playlist.tracks),
               cover_url: live_playlist.cover_url
             },
             playlist
           ),
         {:ok, _} <- Mailer.deliver(build_email(playlist, email, html)) do
      :ok
    else
      nil -> {:error, :not_found}
      {:error, _} = err -> err
    end
  end

  defp build_email(playlist, recipient, html) do
    new()
    |> to({"", recipient})
    |> from({"Premiere Ecoute", "onboarding@resend.dev"})
    |> subject("Playlist: #{playlist.title}")
    |> html_body(html)
  end
end
