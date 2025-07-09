defmodule PremiereEcouteWeb.Admin.AdminAlbumsLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Discography.Album

  def mount(_params, _session, socket) do
    albums = list_albums()

    socket
    |> assign(:page_title, "Admin Albums")
    |> assign(:albums, albums)
    |> assign(:selected_album, nil)
    |> assign(:show_modal, false)
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_event("show_album_modal", %{"album_id" => album_id}, socket) do
    album = Album.get(String.to_integer(album_id))

    socket
    |> assign(:selected_album, album)
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
    |> String.to_integer()
    |> Album.get()
    |> Repo.delete()
    |> case do
      {:ok, _} ->
        socket
        |> assign(:albums, list_albums())
        |> put_flash(:info, "Album deleted successfully")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _} ->
        socket
        |> put_flash(
          :error,
          "Cannot delete album - it may be referenced by listening sessions or other records"
        )
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  defp list_albums do
    Album
    |> Repo.all()
    |> Repo.preload(:tracks)
    |> Enum.sort_by(& &1.name)
  end

  defp format_duration(duration_ms) when is_integer(duration_ms) do
    seconds = div(duration_ms, 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(remaining_seconds), 2, "0")}"
  end

  defp format_duration(_), do: "--"
end
