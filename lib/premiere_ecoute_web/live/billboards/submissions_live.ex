defmodule PremiereEcouteWeb.Billboards.SubmissionsLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Billboards.Billboard

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket) do
    if user.twitch do
      socket
      |> assign(:billboards, Billboard.submissions(user.twitch.username))
      |> assign(:current_user, user)
    else
      socket
      |> put_flash(:error, "Connect to Twitch")
      |> redirect(to: ~p"/home")
    end
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event(
        "delete",
        %{"billboard_id" => billboard_id, "submission_index" => submission_index},
        %{assigns: %{current_scope: %{user: user}}} = socket
      ) do
    billboard_id
    |> PremiereEcoute.Billboards.get_billboard()
    |> PremiereEcoute.Billboards.remove_submission(String.to_integer(submission_index))
    |> case do
      {:ok, _} ->
        socket
        |> assign(:billboards, Billboard.submissions(user.twitch.username))
        |> put_flash(:info, "Submission deleted successfully")

      {:error, _} ->
        socket
        |> put_flash(:error, "Failed to delete submission")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end
end
