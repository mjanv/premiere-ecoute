defmodule PremiereEcouteWeb.Sessions.SessionsLive do
  @moduledoc """
  User sessions list LiveView.

  Displays paginated list of user's listening sessions with status indicators, visibility badges, navigation to session details, and deletion with confirmation modal.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Sessions.Components.ReplaySlots

  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Services.ReplayVideo

  @statuses %{"preparing" => :preparing, "active" => :active, "stopped" => :stopped}
  @sources %{"album" => :album, "playlist" => :playlist, "track" => :track, "clip" => :clip, "free" => :free}

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: scope}} = socket) do
    if connected?(socket), do: PremiereEcoute.PubSub.subscribe("uploads:#{scope.user.id}")

    socket
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> assign(:pasting, nil)
    |> assign(:paste_error, nil)
    |> assign(:checking, MapSet.new())
    |> apply_filters(%{})
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply, apply_filters(socket, parse_filters(params))}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    {:noreply, apply_filters(socket, %{})}
  end

  @impl true
  def handle_event("next-page", _params, %{assigns: %{current_scope: scope, page: page, filters: filters}} = socket) do
    next_page = ListeningSession.next_page_for_user(scope.user.id, page, filters)

    socket
    |> assign(:page, next_page)
    |> stream(:sessions, next_page.entries)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("navigate", %{"session_id" => share_token}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/sessions/#{share_token}/dashboard")}
  end

  @impl true
  def handle_event("replay_action", %{"action" => action, "session_id" => session_id, "replay_id" => replay_id}, socket) do
    case owned_session(socket, session_id) do
      nil -> {:noreply, put_flash(socket, :error, gettext("Session not found"))}
      session -> {:noreply, replay_action(action, session, replay_id, socket)}
    end
  end

  @impl true
  def handle_event("attach_replay", %{"session_id" => session_id, "replay_id" => replay_id, "url" => url}, socket) do
    case owned_session(socket, session_id) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Session not found"))}

      session ->
        case Sessions.attach_upload(session.id, replay_id, String.trim(url)) do
          {:ok, _session} ->
            {:noreply,
             socket
             |> assign(:pasting, nil)
             |> assign(:paste_error, nil)
             |> put_flash(:info, gettext("Replay linked"))
             |> refresh(session.id)}

          {:error, reason} ->
            {:noreply, socket |> assign(:paste_error, attach_error(reason)) |> refresh(session.id)}
        end
    end
  end

  @impl true
  def handle_event("delete_session", %{"session_id" => session_id}, socket) do
    socket
    |> assign(:show_delete_modal, true)
    |> assign(:session_to_delete, session_id)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    socket
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("confirm_delete", _params, %{assigns: %{session_to_delete: session_id}} = socket) do
    session = ListeningSession.get(session_id)

    socket =
      case ListeningSession.delete(session) do
        {:ok, deleted_session} ->
          if deleted_session.playlist do
            Playlist.delete(deleted_session.playlist)
          end

          socket
          |> put_flash(:info, "Session deleted successfully")
          |> stream_delete(:sessions, deleted_session)

        {:error, _} ->
          put_flash(socket, :error, "Failed to delete session")
      end

    socket
    |> assign(:show_delete_modal, false)
    |> assign(:session_to_delete, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:replay_checked, session_id, replay_id, result}, socket) do
    socket =
      socket
      |> update(:checking, &MapSet.delete(&1, {session_id, replay_id}))
      |> refresh(session_id)

    case result do
      :found -> put_flash(socket, :info, gettext("Replay found"))
      :not_found -> put_flash(socket, :info, gettext("Replay not found"))
      :error -> put_flash(socket, :error, gettext("YouTube could not be reached"))
      :settled -> socket
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_info({:replay_updated, session_id, _replay_id}, socket), do: {:noreply, refresh(socket, session_id)}

  def handle_info({:check_timeout, session_id, replay_id}, socket) do
    if MapSet.member?(socket.assigns.checking, {session_id, replay_id}) do
      {:noreply,
       socket
       |> update(:checking, &MapSet.delete(&1, {session_id, replay_id}))
       |> put_flash(:error, gettext("The check did not answer"))
       |> refresh(session_id)}
    else
      {:noreply, socket}
    end
  end

  @doc """
  Returns the id of the replay whose link form is open on `session`, if any.
  """
  @spec pasting_for({integer(), String.t()} | nil, ListeningSession.t()) :: String.t() | nil
  def pasting_for({session_id, replay_id}, %ListeningSession{id: session_id}), do: replay_id
  def pasting_for(_pasting, _session), do: nil

  @doc """
  Returns the ids of the replays of `session` being checked now.
  """
  @spec checking_for(MapSet.t(), ListeningSession.t()) :: [String.t()]
  def checking_for(checking, %ListeningSession{id: session_id}) do
    for {^session_id, replay_id} <- checking, do: replay_id
  end

  @doc """
  Returns how many replays of `session` are missing.
  """
  @spec missing_count(ListeningSession.t()) :: non_neg_integer()
  def missing_count(session), do: ReplayVideo.missing_count(session)

  @doc """
  Returns how many replays of `session` need the streamer.
  """
  @spec attention_count(ListeningSession.t()) :: non_neg_integer()
  def attention_count(session), do: ReplayVideo.attention_count(session)

  @doc """
  Returns the filters of the filter form as the backend expects them.

  Unknown status and source values are dropped, a blank search is dropped. Nothing is read from the URL: the filters live in the `:filters` assign.
  """
  @spec parse_filters(map()) :: %{optional(:q) => String.t(), optional(:status) => atom(), optional(:source) => atom()}
  def parse_filters(params) do
    [q: search_term(params["q"]), status: @statuses[params["status"]], source: @sources[params["source"]]]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp search_term(q) when is_binary(q), do: if(String.trim(q) == "", do: nil, else: String.trim(q))
  defp search_term(_q), do: nil

  defp apply_filters(%{assigns: %{current_scope: scope}} = socket, filters) do
    page = ListeningSession.page_for_user(scope.user.id, 1, 10, filters)

    socket
    |> assign(:filters, filters)
    |> assign(:page, page)
    |> stream(:sessions, page.entries, reset: true)
  end

  @doc """
  Returns the status values and labels offered by the status filter.
  """
  @spec status_options() :: [{String.t(), String.t()}]
  def status_options,
    do: [{"preparing", gettext("Preparing")}, {"active", gettext("Active")}, {"stopped", gettext("Stopped")}]

  @doc """
  Returns the source values and labels offered by the source filter.
  """
  @spec source_options() :: [{String.t(), String.t()}]
  def source_options,
    do: [
      {"album", gettext("Album")},
      {"playlist", gettext("Playlist")},
      {"track", gettext("Track")},
      {"clip", gettext("Clip")},
      {"free", gettext("Free")}
    ]

  defp replay_action("paste", session, replay_id, socket) do
    previous = socket.assigns.pasting

    socket
    |> assign(:pasting, {session.id, replay_id})
    |> assign(:paste_error, nil)
    |> refresh(session.id)
    |> refresh_previous(previous, session.id)
  end

  defp replay_action("cancel", session, _replay_id, socket) do
    socket |> assign(:pasting, nil) |> assign(:paste_error, nil) |> refresh(session.id)
  end

  defp replay_action("check", session, replay_id, socket) do
    case Sessions.check_upload_now(session.id, replay_id) do
      {:ok, _job} ->
        Process.send_after(self(), {:check_timeout, session.id, replay_id}, 20_000)
        socket |> update(:checking, &MapSet.put(&1, {session.id, replay_id})) |> refresh(session.id)

      {:error, _reason} ->
        socket |> put_flash(:error, gettext("This replay changed, nothing was done")) |> refresh(session.id)
    end
  end

  defp replay_action(action, session, replay_id, socket) when action in ~w(skip unskip retry unmark) do
    case run_replay_action(action, session.id, replay_id) do
      {:ok, _session} ->
        refresh(socket, session.id)

      {:error, _reason} ->
        socket |> put_flash(:error, gettext("This replay changed, nothing was done")) |> refresh(session.id)
    end
  end

  defp run_replay_action("skip", session_id, replay_id), do: Sessions.skip_upload(session_id, replay_id)
  defp run_replay_action("unskip", session_id, replay_id), do: Sessions.unskip_upload(session_id, replay_id)
  defp run_replay_action("retry", session_id, replay_id), do: Sessions.retry_upload(session_id, replay_id)
  defp run_replay_action("unmark", session_id, replay_id), do: Sessions.unmark_upload(session_id, replay_id)

  defp attach_error(:invalid_url), do: gettext("This is not a YouTube video link")
  defp attach_error(:video_not_found), do: gettext("Video not found, or not public yet")

  defp attach_error({:wrong_channel, title}),
    do: gettext("This video is on %{title}, not on the channel of this replay", title: title)

  defp attach_error(:duplicate), do: gettext("This video is already linked to this session")
  defp attach_error(_reason), do: gettext("The replay could not be linked")

  defp owned_session(socket, session_id) do
    with {id, ""} <- Integer.parse(to_string(session_id)),
         %ListeningSession{user_id: user_id} = session <- ListeningSession.get(id),
         true <- user_id == socket.assigns.current_scope.user.id do
      session
    else
      _ -> nil
    end
  end

  defp refresh(socket, session_id) do
    case session_id |> ListeningSession.get() |> ListeningSession.preload() do
      %ListeningSession{} = session -> stream_insert(socket, :sessions, session)
      nil -> socket
    end
  end

  defp refresh_previous(socket, {previous_id, _replay_id}, session_id) when previous_id != session_id,
    do: refresh(socket, previous_id)

  defp refresh_previous(socket, _previous, _session_id), do: socket

  @doc """
  Returns the heroicon name for a session status badge.
  """
  @spec session_status_icon(atom()) :: String.t()
  def session_status_icon(:preparing), do: "hero-clock"
  def session_status_icon(:active), do: "hero-musical-note"
  def session_status_icon(:stopped), do: "hero-stop"

  @doc """
  Returns Tailwind CSS classes for session visibility badge.

  Maps visibility atoms to appropriate color scheme classes for visual indicators (red for private, blue for protected, green for public).
  """
  @spec visibility_class(atom()) :: String.t()
  def visibility_class(:private), do: "bg-red-600/20 text-red-400 border-red-500/30"
  def visibility_class(:protected), do: "bg-blue-600/20 text-blue-400 border-blue-500/30"
  def visibility_class(:public), do: "bg-green-600/20 text-green-400 border-green-500/30"

  @doc """
  Returns emoji icon for session visibility level.

  Maps visibility atoms to emoji icons for visual representation (lock for private, shield for protected, globe for public).
  """
  @spec visibility_icon(atom()) :: String.t()
  def visibility_icon(:private), do: "🔒"
  def visibility_icon(:protected), do: "🛡️"
  def visibility_icon(:public), do: "🌐"

  @doc """
  Returns human-readable label for session visibility level.

  Maps visibility atoms to capitalized string labels for display (Private, Protected, Public).
  """
  @spec visibility_label(atom()) :: String.t()
  def visibility_label(:private), do: "Private"
  def visibility_label(:protected), do: "Protected"
  def visibility_label(:public), do: "Public"
end
