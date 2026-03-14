defmodule PremiereEcouteWeb.Accounts.UsersLive do
  @moduledoc """
  Public directory of user accounts.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :streamers, Accounts.streamers())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page_number = String.to_integer(params["page"] || "1")
    {:noreply, assign(socket, :page, Accounts.page_members(page_number, @page_size))}
  end
end
