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
         true <- tracks_visible?(user) do
      # AIDEV-NOTE: tracks/date assigned here for initial render; handle_params refreshes on patch
      retention_days = user.profile.radio_settings.retention_days
      today = Date.utc_today()

      {:ok,
       assign(socket,
         user: user,
         date: date,
         tracks: [],
         today: today,
         oldest_date: Date.add(today, -(retention_days - 1)),
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

  defp tracks_visible?(user) do
    case user.profile.radio_settings do
      %{visibility: :public} -> true
      _ -> false
    end
  end
end
