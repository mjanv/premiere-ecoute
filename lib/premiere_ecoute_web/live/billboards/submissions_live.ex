defmodule PremiereEcouteWeb.Billboards.SubmissionsLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  import Ecto.Query

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket) do
    socket
    |> assign(:billboards, query(user.twitch.username))
    |> assign(:current_user, user)
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
        |> assign(:billboards, query(user.twitch.username))
        |> put_flash(:info, "Submission deleted successfully")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _} ->
        socket
        |> put_flash(:error, "Failed to delete submission")
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  defp query(pseudo) do
    query =
      from b in PremiereEcoute.Billboards.Billboard,
        where:
          fragment(
            "EXISTS (SELECT 1 FROM jsonb_array_elements(?) elem WHERE elem->>'pseudo' = ?)",
            b.submissions,
            ^pseudo
          )

    query
    |> PremiereEcoute.Repo.all()
    |> PremiereEcoute.Repo.preload([:streamer])
    |> Enum.map(fn billboard ->
      billboard.submissions
      |> Enum.with_index()
      |> Enum.map(fn {submission, i} -> Map.put(submission, "index", i) end)
      |> Enum.filter(fn submission -> submission["pseudo"] == pseudo end)
      |> then(fn submissions -> Map.put(billboard, :submissions, submissions) end)
    end)
  end
end
