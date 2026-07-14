defmodule PremiereEcouteWeb.Sessions.ClipOverlayLive do
  @moduledoc """
  OBS streaming overlay LiveView for YouTube clip listening sessions.

  Renders a full-bleed, chrome-less YouTube IFrame player for the active :clip
  session's video, meant to be added as its own OBS Browser Source (separate
  from the stats overlay at /sessions/overlay/:username). Purely fire-and-forget:
  no playback state is tracked or pushed back to the server.

  Always renders a solid black background (never transparent, so OBS never
  shows passthrough). Shows the clip's thumbnail while the session is prepared
  but not yet started, and swaps to the live YouTube player once it starts.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Sessions.ListeningSession

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    user = Accounts.User.get_user_by_username(username)

    if is_nil(user) do
      {:ok, redirect(socket, to: "/")}
    else
      mount_with_user(user, socket)
    end
  end

  defp mount_with_user(user, socket) do
    if connected?(socket) do
      PremiereEcoute.PubSub.subscribe("playback:#{user.id}")
    end

    session = clip_session(user)

    if connected?(socket) && session do
      PremiereEcoute.PubSub.subscribe("session:#{session.id}")
    end

    socket
    |> assign(:user, user)
    |> assign(:session_id, session && session.id)
    |> assign(:youtube_video_id, playing_video_id(session))
    |> assign(:thumbnail_url, thumbnail_url(session))
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_info({:session_prepared, session_id}, socket) do
    session = ListeningSession.get(session_id)

    if connected?(socket) do
      PremiereEcoute.PubSub.subscribe("session:#{session_id}")
    end

    socket
    |> assign(:session_id, session_id)
    |> assign(:youtube_video_id, playing_video_id(session))
    |> assign(:thumbnail_url, thumbnail_url(session))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_info({:session_started, session_id}, socket) do
    session = ListeningSession.get(session_id)

    if connected?(socket) do
      PremiereEcoute.PubSub.subscribe("session:#{session_id}")
    end

    socket
    |> assign(:session_id, session_id)
    |> assign(:youtube_video_id, playing_video_id(session))
    |> assign(:thumbnail_url, thumbnail_url(session))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_info({:session_stopped, _session_id}, socket) do
    socket
    |> assign(:youtube_video_id, nil)
    |> assign(:thumbnail_url, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_info(:stop, socket) do
    socket
    |> assign(:youtube_video_id, nil)
    |> assign(:thumbnail_url, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_info({:clip_command, command}, socket) do
    {:noreply, push_event(socket, "clip_command", command)}
  end

  def handle_info(_event, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "clip_progress",
        %{"current_time" => current_time, "duration" => duration, "playing" => playing},
        socket
      ) do
    if socket.assigns.session_id do
      PremiereEcoute.PubSub.broadcast(
        "session:#{socket.assigns.session_id}",
        {:clip_progress, %{current_time: current_time, duration: duration, playing: playing}}
      )
    end

    {:noreply, socket}
  end

  defp clip_session(user) do
    case ListeningSession.current_session(user) do
      %ListeningSession{source: :clip} = session -> session
      _ -> nil
    end
  end

  defp playing_video_id(%ListeningSession{status: :active} = session), do: clip_video_id(session)
  defp playing_video_id(_session), do: nil

  defp thumbnail_url(%ListeningSession{options: options}), do: options["clip_thumbnail_url"]
  defp thumbnail_url(_session), do: nil

  defp clip_video_id(%ListeningSession{source: :clip, single: %{provider_ids: provider_ids}}) do
    Map.get(provider_ids, :youtube)
  end

  defp clip_video_id(_session), do: nil
end
