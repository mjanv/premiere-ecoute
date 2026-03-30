defmodule PremiereEcouteWeb.Discography.SingleLive do
  @moduledoc """
  Single detail page — shows single metadata and listening sessions that used it.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Wantlists

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    single = Discography.get_single_by_slug(slug)

    if is_nil(single) do
      {:ok, push_navigate(socket, to: ~p"/discography/singles")}
    else
      sessions = ListeningSession.list_for_single(single.id)

      current_user = socket.assigns[:current_scope] && socket.assigns.current_scope.user

      in_wantlist =
        if current_user,
          do: Wantlists.in_wantlist?(current_user.id, :track, single.id),
          else: false

      {:ok,
       socket
       |> assign(:single, single)
       |> assign(:sessions, sessions)
       |> assign(:in_wantlist, in_wantlist)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_wantlist_single", _params, socket) do
    user = socket.assigns.current_scope.user
    single = socket.assigns.single

    if socket.assigns.in_wantlist do
      case Wantlists.remove_item(user.id, :track, single.id) do
        {:ok, _} -> {:noreply, assign(socket, :in_wantlist, false)}
        {:error, _} -> {:noreply, put_flash(socket, :error, gettext("Could not remove from wantlist"))}
      end
    else
      case Wantlists.add_item(user.id, :track, single.id) do
        {:ok, _} -> {:noreply, assign(socket, :in_wantlist, true)}
        {:error, _} -> {:noreply, put_flash(socket, :error, gettext("Could not add to wantlist"))}
      end
    end
  end
end
