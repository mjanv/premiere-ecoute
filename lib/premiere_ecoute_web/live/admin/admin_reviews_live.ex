defmodule PremiereEcouteWeb.Admin.AdminReviewsLive do
  @moduledoc """
  Admin reviews management LiveView.

  Provides paginated review listing with statistics for administrators.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Admin.Pagination, only: [pagination_range: 2]

  alias PremiereEcoute.Sessions.ListeningSession.Review

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:search, "")
    |> assign(:page, Review.list_for_admin("", 1, 20))
    |> assign(:review_stats, review_stats())
    |> assign(:selected_review, nil)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(params, _url, socket) do
    page_number = String.to_integer(params["page"] || "1")
    page_size = String.to_integer(params["per_page"] || "20")

    socket
    |> assign(:page, Review.list_for_admin(socket.assigns.search, page_number, page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("search", %{"search" => search}, %{assigns: %{page: page}} = socket) do
    socket
    |> assign(:search, search)
    |> assign(:page, Review.list_for_admin(search, 1, page.page_size))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("show_review", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_review, Review.get(id))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :selected_review, nil)}
  end

  def handle_event("delete_review", %{"id" => id}, %{assigns: %{page: page, search: search}} = socket) do
    id
    |> Review.get()
    |> Review.delete()
    |> case do
      {:ok, _} ->
        socket
        |> assign(:selected_review, nil)
        |> assign(:page, Review.list_for_admin(search, page.page_number, page.page_size))
        |> assign(:review_stats, review_stats())
        |> put_flash(:info, gettext("Review deleted"))

      {:error, _} ->
        put_flash(socket, :error, gettext("Could not delete review"))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  defp review_stats do
    avg =
      case Review.average(:rating) do
        nil -> 0.0
        %Decimal{} = dec -> dec |> Decimal.to_float() |> Float.round(2)
        f when is_float(f) -> Float.round(f, 2)
      end

    %{total_reviews: Review.count(:id), average_rating: avg}
  end
end
