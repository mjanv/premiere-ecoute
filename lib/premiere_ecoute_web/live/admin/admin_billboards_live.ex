defmodule PremiereEcouteWeb.Admin.AdminBillboardsLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Billboards
  alias PremiereEcoute.Billboards.Billboard

  def mount(_params, _session, socket) do
    billboards = Billboard.all(order_by: [desc: :updated_at])

    socket
    |> assign(:billboards, billboards)
    |> assign(:billboard_stats, billboard_stats(billboards))
    |> assign(:selected_billboard, nil)
    |> assign(:show_billboard_modal, false)
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_event("show_billboard_modal", %{"billboard_id" => billboard_id}, socket) do
    billboard =
      socket.assigns.billboards
      |> Enum.find(&(&1.id == String.to_integer(billboard_id)))

    socket
    |> assign(:selected_billboard, billboard)
    |> assign(:show_billboard_modal, true)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("close_billboard_modal", _params, socket) do
    socket
    |> assign(:selected_billboard, nil)
    |> assign(:show_billboard_modal, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("modal_content_click", _params, socket), do: {:noreply, socket}

  def handle_event("change_status", %{"billboard_id" => billboard_id, "status" => status}, socket) do
    billboard = socket.assigns.billboards |> Enum.find(&(&1.id == String.to_integer(billboard_id)))

    case Billboards.update_billboard(billboard, %{status: String.to_existing_atom(status)}) do
      {:ok, updated_billboard} ->
        billboards = Billboard.all(order_by: [desc: :updated_at])

        socket
        |> assign(:billboards, billboards)
        |> assign(:billboard_stats, billboard_stats(billboards))
        |> assign(:selected_billboard, updated_billboard)
        |> put_flash(:info, gettext("Billboard status updated successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("Failed to update billboard status"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_event("remove_submission", %{"billboard_id" => billboard_id, "index" => index}, socket) do
    billboard = socket.assigns.billboards |> Enum.find(&(&1.id == String.to_integer(billboard_id)))

    case Billboards.remove_submission(billboard, String.to_integer(index)) do
      {:ok, updated_billboard} ->
        billboards = Billboard.all(order_by: [desc: :updated_at])

        socket
        |> assign(:billboards, billboards)
        |> assign(:billboard_stats, billboard_stats(billboards))
        |> assign(:selected_billboard, updated_billboard)
        |> put_flash(:info, gettext("Submission removed successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("Failed to remove submission"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_event("toggle_submission_review", %{"billboard_id" => billboard_id, "index" => index}, socket) do
    billboard = socket.assigns.billboards |> Enum.find(&(&1.id == String.to_integer(billboard_id)))

    case Billboards.toggle_submission_review(billboard, String.to_integer(index)) do
      {:ok, updated_billboard} ->
        billboards = Billboard.all(order_by: [desc: :updated_at])

        socket
        |> assign(:billboards, billboards)
        |> assign(:billboard_stats, billboard_stats(billboards))
        |> assign(:selected_billboard, updated_billboard)
        |> put_flash(:info, gettext("Submission review status updated"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("Failed to update submission review"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_event("confirm_delete_billboard", %{"billboard_id" => billboard_id}, socket) do
    billboard = socket.assigns.billboards |> Enum.find(&(&1.id == String.to_integer(billboard_id)))

    case Billboards.delete_billboard(billboard) do
      {:ok, _} ->
        billboards = Billboard.all(order_by: [desc: :updated_at])

        socket
        |> assign(:billboards, billboards)
        |> assign(:billboard_stats, billboard_stats(billboards))
        |> assign(:selected_billboard, nil)
        |> assign(:show_billboard_modal, false)
        |> put_flash(:info, gettext("Billboard has been deleted successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _reason} ->
        socket
        |> put_flash(:error, gettext("Failed to delete billboard"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def billboard_stats(billboards) do
    status_stats =
      billboards
      |> Enum.group_by(& &1.status)
      |> Enum.into(%{}, fn {status, billboards} -> {status, length(billboards)} end)

    total_submissions =
      billboards
      |> Enum.map(&length(&1.submissions || []))
      |> Enum.sum()

    Map.put(status_stats, :total_submissions, total_submissions)
  end

  def format_datetime(datetime) do
    datetime
    |> DateTime.shift_zone!("Europe/Paris")
    |> Calendar.strftime("%d/%m/%Y %H:%M")
  end

  def submission_reviewed?(%{"reviewed" => reviewed}) when is_boolean(reviewed), do: reviewed
  def submission_reviewed?(%{reviewed: reviewed}) when is_boolean(reviewed), do: reviewed
  def submission_reviewed?(_), do: false

  def status_color(:created), do: "bg-yellow-100 text-yellow-800"
  def status_color(:active), do: "bg-green-100 text-green-800"
  def status_color(:stopped), do: "bg-red-100 text-red-800"
  def status_color(_), do: "bg-gray-100 text-gray-800"
end
