defmodule PremiereEcouteWeb.Admin.AdminReviewsLive do
  @moduledoc """
  Admin reviews management LiveView.

  Provides paginated review listing with statistics for administrators.
  """

  use PremiereEcouteWeb, :live_view

  import Ecto.Query
  import PremiereEcouteWeb.Admin.Pagination, only: [pagination_range: 2]

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession.Review

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page, list_reviews(1, 20))
    |> assign(:reviews_count, Review.count(:id))
    |> assign(:selected_review, nil)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(params, _url, socket) do
    page_number = String.to_integer(params["page"] || "1")
    page_size = String.to_integer(params["per_page"] || "20")

    socket
    |> assign(:page, list_reviews(page_number, page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("show_review", %{"id" => id}, socket) do
    review = Repo.get!(Review, id) |> Repo.preload([:user, :album, :likes])
    {:noreply, assign(socket, :selected_review, review)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :selected_review, nil)}
  end

  def handle_event("delete_review", %{"id" => id}, %{assigns: %{page: page}} = socket) do
    review = Repo.get!(Review, id)

    case Repo.delete(review) do
      {:ok, _} ->
        socket
        |> assign(:selected_review, nil)
        |> assign(:page, list_reviews(page.page_number, page.page_size))
        |> assign(:reviews_count, Review.count(:id))
        |> put_flash(:info, gettext("Review deleted"))

      {:error, _} ->
        put_flash(socket, :error, gettext("Could not delete review"))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  # AIDEV-NOTE: Review.page preloads [:user, :likes] from root; album is added here
  defp list_reviews(page, page_size) do
    Review
    |> order_by(desc: :inserted_at)
    |> preload([:user, :album, :likes])
    |> Repo.paginate(page: page, page_size: page_size)
  end
end
