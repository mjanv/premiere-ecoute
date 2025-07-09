defmodule PremiereEcouteWeb.Admin.AdminAlbumsLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Sessions.Discography.Album

  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Admin Albums")
    |> assign(:albums, Album.all())
    |> assign(:selected_album, nil)
    |> assign(:show_modal, false)
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_event("show_album_modal", %{"album_id" => album_id}, socket) do
    socket
    |> assign(:selected_album, Album.get(album_id))
    |> assign(:show_modal, true)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("close_modal", _params, socket) do
    socket
    |> assign(:selected_album, nil)
    |> assign(:show_modal, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("delete_album", %{"album_id" => album_id}, socket) do
    album_id
    |> Album.get()
    |> Album.delete()
    |> case do
      {:ok, _} ->
        socket
        |> assign(:albums, Album.all())
        |> put_flash(:info, "Album deleted successfully")
      {:error, _} ->
        socket
        |> put_flash(:error, "Cannot delete album")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  defp format_duration(duration_ms) when is_integer(duration_ms) do
    seconds = div(duration_ms, 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(remaining_seconds), 2, "0")}"
  end

  defp format_duration(_), do: "--"
end
