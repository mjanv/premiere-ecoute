defmodule PremiereEcouteWeb.Collections.CollectionSessionNewLive do
  @moduledoc """
  New collection session creation LiveView.

  Form to select origin and destination playlists.
  Dispatches PrepareCollectionSession then redirects to the session page.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Collections.CollectionSession.Commands.PrepareCollectionSession
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcouteCore.CommandBus

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: scope}} = socket) do
    playlists = LibraryPlaylist.all_for_user(scope.user)

    socket
    |> assign(:playlists, playlists)
    |> assign(:form, to_form(default_form(), as: :session))
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_duel_reminder", _params, socket) do
    params = socket.assigns.form.params
    updated = Map.put(params, "duel_reminder_enabled", if(params["duel_reminder_enabled"] == "true", do: "false", else: "true"))
    {:noreply, assign(socket, :form, to_form(updated, as: :session))}
  end

  @impl true
  def handle_event("validate", %{"session" => params}, socket) do
    merged = Map.merge(socket.assigns.form.params, params)
    {:noreply, assign(socket, :form, to_form(merged, as: :session))}
  end

  @impl true
  def handle_event("submit", %{"session" => params}, %{assigns: %{current_scope: scope}} = socket) do
    options =
      %{}
      |> then(fn opts ->
        if params["duel_reminder_enabled"] == "true",
          do: Map.put(opts, "duel_reminder_minutes", String.to_integer(params["duel_reminder_minutes"])),
          else: opts
      end)
      |> then(fn opts ->
        if params["duel_sound"] != "", do: Map.put(opts, "duel_sound", params["duel_sound"]), else: opts
      end)

    %PrepareCollectionSession{
      scope: scope,
      origin_playlist_id: parse_id(params["origin_playlist_id"]),
      destination_playlist_id: parse_id(params["destination_playlist_id"]),
      options: options
    }
    |> CommandBus.apply()
    |> case do
      {:ok, session, _events} ->
        {:noreply, push_navigate(socket, to: ~p"/collections/#{session.id}")}

      {:error, reason} ->
        socket
        |> put_flash(:error, gettext("Failed to create collection: %{reason}", reason: inspect(reason)))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  defp default_form do
    %{
      "origin_playlist_id" => "",
      "destination_playlist_id" => "",
      "duel_reminder_enabled" => "false",
      "duel_reminder_minutes" => "30",
      "duel_sound" => ""
    }
  end

  defp parse_id(""), do: nil
  defp parse_id(nil), do: nil
  defp parse_id(val) when is_binary(val), do: String.to_integer(val)
  defp parse_id(val) when is_integer(val), do: val
end
