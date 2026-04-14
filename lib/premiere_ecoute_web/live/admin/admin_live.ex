defmodule PremiereEcouteWeb.Admin.AdminLive do
  @moduledoc """
  Admin dashboard LiveView.

  Displays system statistics, recent activity feed, and links to analytics and event store.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Analytics
  alias PremiereEcoute.Billboards.Billboard
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Donations.Goal
  # AIDEV-NOTE: Album/Artist kept for stats_count; Analytics used for overview chart
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Review

  # AIDEV-NOTE: High-signal events shown in the activity feed — noisy or
  # internal events (e.g. ConsentGiven) are intentionally excluded.
  @feed_events ~w(
    Elixir.PremiereEcoute.Events.AccountCreated
    Elixir.PremiereEcoute.Events.AccountDeleted
    Elixir.PremiereEcoute.Events.AccountAssociated
    Elixir.PremiereEcoute.Events.AddedToWantlist
    Elixir.PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted
    Elixir.PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped
    Elixir.PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionCompleted
  )

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:stats, %{
       users_count: User.count(:id),
       sessions_count: ListeningSession.count(:id),
       albums_count: Album.count(:id),
       artists_count: Artist.count(:id),
       reviews_count: Review.count(:id),
       billboards_count: Billboard.count(:id),
       goals_count: Goal.count(:id)
     })
     |> assign(:feed, load_feed())
     |> assign(:overview_charts, load_overview_charts())}
  end

  defp load_overview_charts do
    to = DateTime.utc_now()
    from = DateTime.add(to, -30, :day)
    opts = [from: from, to: to, fill_gaps: true]

    %{
      all_events: Analytics.aggregate_events(nil, :day, opts)
    }
  end

  defp period_to_iso(dt) when is_struct(dt, DateTime), do: DateTime.to_iso8601(dt)
  defp period_to_iso(ndt) when is_struct(ndt, NaiveDateTime), do: NaiveDateTime.to_iso8601(ndt)

  defp chart_json(rows) do
    rows
    |> Enum.map(&%{period: period_to_iso(&1.period), count: &1.count})
    |> Jason.encode!()
  end

  # AIDEV-NOTE: rescue ArgumentError from JsonbSerializer.keys_to_atoms/1 which
  # crashes on String.to_existing_atom for stale field names in old stored events.
  defp load_feed do
    PremiereEcoute.paginate("$all", page: 1, size: 50)
    |> Enum.filter(&(&1.event_type in @feed_events))
    |> Enum.take(15)
  rescue
    ArgumentError -> []
  end

  defp event_label(%{event_type: type, data: data}) do
    short = type |> String.replace("Elixir.", "") |> String.split(".") |> List.last()

    case {short, data} do
      {"AccountCreated", _} ->
        "New account created"

      {"AccountDeleted", _} ->
        "Account deleted"

      {"AccountAssociated", data} ->
        "Account linked to #{get_field(data, :provider)}"

      {"AddedToWantlist", data} ->
        "Added #{get_field(data, :type)} to wantlist"

      {"SessionStarted", data} ->
        "Session started (#{get_field(data, :source)})"

      {"SessionStopped", _} ->
        "Session stopped"

      {"CollectionSessionCompleted", data} ->
        kept = get_field(data, :kept_count) || 0
        "Collection session completed — #{kept} tracks kept"

      _ ->
        short
    end
  end

  # AIDEV-NOTE: data can be an event struct or a plain map (older stored events)
  defp get_field(data, key) when is_struct(data), do: Map.get(data, key)
  defp get_field(data, key) when is_map(data), do: data[key] || data[to_string(key)]

  defp event_color(%{event_type: type}) do
    cond do
      String.contains?(type, "AccountCreated") -> "text-emerald-400"
      String.contains?(type, "AccountDeleted") -> "text-red-400"
      String.contains?(type, "AccountAssociated") -> "text-sky-400"
      String.contains?(type, "SessionStarted") -> "text-violet-400"
      String.contains?(type, "SessionStopped") -> "text-gray-400"
      String.contains?(type, "AddedToWantlist") -> "text-yellow-400"
      true -> "text-gray-300"
    end
  end
end
