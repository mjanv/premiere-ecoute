defmodule PremiereEcouteWeb.Radio.ViewerLive do
  @moduledoc """
  Public LiveView for viewing daily radio tracks.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Components.Navigation.DayNav

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Radio

  @impl true
  def mount(%{"username" => username} = params, _session, socket) do
    date =
      case params do
        %{"date" => date_str} ->
          case Date.from_iso8601(date_str) do
            {:ok, d} -> d
            _ -> nil
          end

        _ ->
          Date.utc_today()
      end

    with false <- is_nil(date),
         user when not is_nil(user) <- Accounts.get_user_by_username(username),
         :public <- Accounts.profile(user, [:radio_settings, :visibility]) do
      today = Date.utc_today()

      {:ok,
       assign(socket,
         user: user,
         date: date,
         tracks: [],
         today: today,
         oldest_date: Date.add(today, -Accounts.profile(user, [:radio_settings, :retention_days])),
         timezone: Accounts.profile(user, [:timezone], "UTC"),
         page_title: "#{username}'s tracks"
       )}
    else
      _ -> {:ok, push_navigate(socket, to: "/")}
    end
  end

  @impl true
  def handle_params(%{"date" => date_str}, _uri, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        tracks = Radio.get_tracks(socket.assigns.user.id, date)
        {:noreply, assign(socket, date: date, tracks: tracks)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket) do
    date = Date.utc_today()
    tracks = Radio.get_tracks(socket.assigns.user.id, date)
    {:noreply, assign(socket, date: date, tracks: tracks)}
  end
end
