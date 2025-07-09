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
    |> assign(:users, User.all())
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

  def handle_event("toggle_role", %{"user_id" => user_id}, socket) do
    user = User.get!(user_id)
    new_role = if user.role == :admin, do: :streamer, else: :admin

    user
    |> Ecto.Changeset.cast(%{role: new_role}, [:role])
    |> Ecto.Changeset.validate_inclusion(:role, [:streamer, :admin])
    |> Repo.update()
    |> case do
      {:ok, _} -> {:noreply, assign(socket, :users, User.all())}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to update user role")}
    end
  end
end
