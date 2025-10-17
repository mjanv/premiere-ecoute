defmodule PremiereEcouteWeb.Playlists.WorkflowsLive do
  @moduledoc """
  LiveView for managing playlist workflows.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Playlists
  alias PremiereEcoute.Sessions.Retrospective.History

  @impl true
  def mount(_params, _session, socket) do
    current_date = DateTime.utc_now()

    socket
    |> assign(:source, "my_votes")
    |> assign(:source_options, %{
      number_tracks: 50,
      time_range: %{
        period: :month,
        year: current_date.year,
        month: current_date.month
      }
    })
    |> assign(:target, "playlist")
    |> assign(:target_options, %{
      playlist: nil,
      playlists: Discography.LibraryPlaylist.all(where: [user_id: socket.assigns.current_scope.user.id])
    })
    |> assign(:tracks, AsyncResult.ok([]))
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_source", %{"source_type" => source_type}, socket) do
    socket
    |> assign(:source, source_type)
    |> assign(:tracks, AsyncResult.ok([]))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("update_track_count", params, %{assigns: %{source_options: options}} = socket) do
    new_count =
      case params do
        %{"direction" => "decrease"} ->
          max(1, options.number_tracks - 1)

        %{"direction" => "increase"} ->
          min(100, options.number_tracks + 1)

        %{"track_count" => track_count} ->
          case Integer.parse(track_count) do
            {num, _} when num >= 1 and num <= 100 -> num
            _ -> options.number_tracks
          end

        _ ->
          options.number_tracks
      end

    socket
    |> assign(:source_options, %{options | number_tracks: new_count})
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("navigate_month", %{"direction" => direction}, %{assigns: %{source_options: options}} = socket) do
    current_month = options.time_range.month
    current_year = options.time_range.year

    {new_month, new_year} =
      case direction do
        "previous" ->
          if current_month == 1 do
            {12, current_year - 1}
          else
            {current_month - 1, current_year}
          end

        "next" ->
          if current_month == 12 do
            {1, current_year + 1}
          else
            {current_month + 1, current_year}
          end

        _ ->
          {current_month, current_year}
      end

    socket
    |> assign(:source_options, %{options | time_range: %{options.time_range | month: new_month, year: new_year}})
    |> assign(:tracks, AsyncResult.ok([]))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("update_target_type", %{"target_type" => target_type}, socket) do
    socket
    |> assign(:target, target_type)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("update_target", %{"target_playlist" => playlist_id}, %{assigns: %{target_options: options}} = socket) do
    socket
    |> assign(:target_options, %{options | playlist: playlist_id})
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("preview_tracks", _params, socket) do
    %{
      source: source,
      source_options: options,
      current_scope: scope
    } = socket.assigns

    socket
    |> assign_async(:tracks, fn ->
      time_range = %{month: options.time_range.month, year: options.time_range.year}
      tracks = load_tracks(source, options.number_tracks, time_range, scope)
      {:ok, %{tracks: tracks}}
    end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("create_workflow", _params, socket) do
    %{
      tracks: async_tracks,
      target_options: %{playlist: playlist_id},
      current_scope: scope
    } = socket.assigns

    case async_tracks do
      %AsyncResult{result: tracks} when is_list(tracks) ->
        if Enum.empty?(tracks) or is_nil(playlist_id) do
          socket
          |> put_flash(:error, gettext("Please select tracks and a playlist first."))
          |> then(fn socket -> {:noreply, socket} end)
        else
          case Playlists.export_tracks_to_playlist(scope, playlist_id, tracks) do
            {:ok, _result} ->
              socket
              |> put_flash(:info, gettext("Workflow created successfully! Tracks exported to playlist."))
              |> assign(:tracks, AsyncResult.ok([]))
              |> then(fn socket -> {:noreply, socket} end)

            {:error, reason} ->
              socket
              |> put_flash(:error, gettext("Failed to export tracks: %{reason}", reason: inspect(reason)))
              |> then(fn socket -> {:noreply, socket} end)
          end
        end

      _ ->
        socket
        |> put_flash(:error, gettext("Please load tracks first."))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  defp load_tracks("my_votes", count, %{month: month, year: year}, scope) do
    History.get_tracks_by_period(scope.user.twitch.user_id, count, :month, %{year: year, month: month})
  end

  defp format_time_period(%{month: month, year: year}) do
    Date.new!(year, month, 1)
    |> Calendar.strftime("%B %Y")
  end
end
