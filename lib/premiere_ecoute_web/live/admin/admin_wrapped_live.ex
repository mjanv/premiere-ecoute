defmodule PremiereEcouteWeb.Admin.AdminWrappedLive do
  @moduledoc """
  Admin Wrapped LiveView.

  Shows how many viewers are eligible and how many recaps are computed for a year, lists the stored recaps, and lets admins enqueue the computation of every viewer or recompute a single one.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Admin.Pagination, only: [pagination_range: 2]

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Wrapped

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, year: Date.utc_today().year, search: "", page_number: 1)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    year = parse_year(params["year"], socket.assigns.year)
    page_number = parse_int(params["page"], 1)

    {:noreply, socket |> assign(year: year, page_number: page_number) |> load()}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, socket |> assign(search: search, page_number: 1) |> load()}
  end

  def handle_event("refresh", _params, socket), do: {:noreply, load(socket)}

  def handle_event("compute_all", _params, %{assigns: %{year: year}} = socket) do
    Wrapped.schedule(year)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Computation of every eligible viewer enqueued"))
     |> load()}
  end

  def handle_event("recompute", %{"id" => id}, %{assigns: %{year: year}} = socket) do
    with %User{} = user <- User.get(id),
         {:ok, _job} <- Wrapped.request_recap(user, year) do
      {:noreply, socket |> put_flash(:info, gettext("Recompute enqueued for %{user}", user: user.username)) |> load()}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not enqueue the recompute"))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    with %{} = recap <- Wrapped.fetch_recap(id),
         {:ok, _recap} <- Wrapped.delete_recap(recap) do
      {:noreply, socket |> put_flash(:info, gettext("Recap deleted")) |> load()}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not delete the recap"))}
    end
  end

  defp load(%{assigns: %{year: year, search: search, page_number: page_number}} = socket) do
    assign(socket,
      page: Wrapped.list_recaps(year, search, page_number, @page_size),
      stats: Wrapped.recap_stats(year),
      eligible: length(Wrapped.eligible_ids(year)),
      pending: Wrapped.pending(),
      years: Enum.to_list(Date.utc_today().year..2026//-1)
    )
  end

  defp parse_year(value, default) do
    year = parse_int(value, default)
    if Wrapped.year?(year), do: year, else: default
  end

  defp parse_int(value, default) do
    case Integer.parse(to_string(value)) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end
end
