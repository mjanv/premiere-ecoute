defmodule PremiereEcouteWeb.Admin.AdminLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.Scores

  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Admin Dashboard")
    |> assign(:stats, get_stats())
    |> then(fn socket -> {:ok, socket} end)
  end

  defp get_stats do
    %{
      users_count: Repo.aggregate(User, :count, :id),
      sessions_count: Sessions.ListeningSession.count(:id),
      albums_count: Album.count(:id),
      votes_count: Scores.Vote.count(:id),
      polls_count: Scores.Poll.count(:id)
    }
  end
end
