defmodule PremiereEcouteWeb.Collections.CollectionSessionNewLive do
  @moduledoc """
  New collection session creation LiveView.

  Form to configure origin/destination playlists, rule, selection mode, and vote duration.
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
    |> assign(:form, to_form(default_form_params()))
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"session" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: :session))}
  end

  @impl true
  def handle_event("submit", %{"session" => params}, %{assigns: %{current_scope: scope}} = socket) do
    origin_id = parse_id(params["origin_playlist_id"])
    destination_id = parse_id(params["destination_playlist_id"])

    command = %PrepareCollectionSession{
      scope: scope,
      origin_playlist_id: origin_id,
      destination_playlist_id: destination_id,
      rule: :ordered,
      selection_mode: :streamer_choice,
      vote_duration: 60
    }

    case CommandBus.apply(command) do
      {:ok, session, _events} ->
        {:noreply, push_navigate(socket, to: ~p"/collections/#{session.id}")}

      {:error, reason} ->
        socket
        |> put_flash(:error, gettext("Failed to create collection: %{reason}", reason: inspect(reason)))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  defp default_form_params do
    %{
      "origin_playlist_id" => "",
      "destination_playlist_id" => ""
    }
  end

  defp parse_id(""), do: nil
  defp parse_id(nil), do: nil
  defp parse_id(val) when is_binary(val), do: String.to_integer(val)
  defp parse_id(val) when is_integer(val), do: val
end
