defmodule PremiereEcouteWeb.Admin.AdminAnalyticsLive do
  @moduledoc """
  Analytics hub for the admin section.

  Displays time-series analytics grouped by bounded context:
  Accounts, Sessions, Discography, Wantlists, Donations.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Analytics
  alias PremiereEcoute.Collections.CollectionSession.Events, as: CollectionEvents
  alias PremiereEcoute.Events.AccountAssociated
  alias PremiereEcoute.Events.AccountCreated
  alias PremiereEcoute.Events.AccountDeleted
  alias PremiereEcoute.Events.AddedToWantlist
  alias PremiereEcoute.Events.AlbumAdded
  alias PremiereEcoute.Events.ArtistAdded
  alias PremiereEcoute.Events.RemovedFromWantlist
  alias PremiereEcoute.Events.UserLoggedIn
  alias PremiereEcoute.Sessions.ListeningSession.Events, as: SessionEvents

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:range, "12m")
      |> assign(:active_context, "accounts")
      |> load_analytics("12m")

    {:ok, socket}
  end

  @impl true
  def handle_event("set_range", %{"range" => range}, socket) when range in ["14d", "30d", "90d", "3m", "6m", "12m", "all"] do
    {:noreply, socket |> assign(:range, range) |> load_analytics(range)}
  end

  def handle_event("set_context", %{"context" => context}, socket) do
    {:noreply, assign(socket, :active_context, context)}
  end

  # ---------------------------------------------------------------------------
  # Data loading
  # ---------------------------------------------------------------------------

  defp load_analytics(socket, range) do
    {from_dt, to_dt} = date_range(range)
    unit = range_unit(range)
    opts = date_opts(from_dt, to_dt)
    # AIDEV-NOTE: gap_opts adds fill_gaps: true only when a date range is set.
    # Grouped queries (fields:) cannot use fill_gaps — passed plain opts instead.
    gap_opts = gap_opts(from_dt, to_dt, opts)

    socket
    |> assign(:unit, unit)
    |> assign(:accounts_data, load_accounts(opts, gap_opts, unit))
    |> assign(:sessions_data, load_sessions(opts, gap_opts, unit))
    |> assign(:discography_data, load_discography(gap_opts, unit))
    |> assign(:wantlists_data, load_wantlists(opts, gap_opts, unit))
  end

  defp load_accounts(opts, gap_opts, unit) do
    created = Analytics.aggregate_events(AccountCreated, unit, gap_opts)
    deleted = Analytics.aggregate_events(AccountDeleted, unit, gap_opts)
    associated = Analytics.aggregate_events(AccountAssociated, unit, Keyword.merge(opts, fields: [:provider]))
    logins = Analytics.aggregate_events(UserLoggedIn, unit, gap_opts)

    %{
      created: created,
      deleted: deleted,
      associated: associated,
      logins: logins,
      total_created: Enum.sum(Enum.map(created, & &1.count)),
      total_deleted: Enum.sum(Enum.map(deleted, & &1.count)),
      total_logins: Enum.sum(Enum.map(logins, & &1.count))
    }
  end

  defp load_sessions(opts, gap_opts, unit) do
    started = Analytics.aggregate_events(SessionEvents.SessionStarted, unit, Keyword.merge(opts, fields: [:source]))
    stopped = Analytics.aggregate_events(SessionEvents.SessionStopped, unit, gap_opts)
    votes = Analytics.aggregate_events(SessionEvents.VoteWindowOpened, unit, Keyword.merge(opts, fields: [:vote_mode]))
    decisions = Analytics.aggregate_events(CollectionEvents.TrackDecided, unit, Keyword.merge(opts, fields: [:decision]))

    %{
      started: started,
      stopped: stopped,
      votes: votes,
      decisions: decisions,
      total_started: Enum.sum(Enum.map(Analytics.aggregate_events(SessionEvents.SessionStarted, unit, opts), & &1.count)),
      total_votes: Enum.sum(Enum.map(Analytics.aggregate_events(SessionEvents.VoteWindowOpened, unit, opts), & &1.count))
    }
  end

  defp load_discography(gap_opts, unit) do
    albums = Analytics.aggregate_events(AlbumAdded, unit, gap_opts)
    artists = Analytics.aggregate_events(ArtistAdded, unit, gap_opts)

    %{
      albums: albums,
      artists: artists,
      total_albums: Enum.sum(Enum.map(albums, & &1.count)),
      total_artists: Enum.sum(Enum.map(artists, & &1.count))
    }
  end

  defp load_wantlists(opts, gap_opts, unit) do
    added = Analytics.aggregate_events(AddedToWantlist, unit, Keyword.merge(opts, fields: [:type]))
    removed = Analytics.aggregate_events(RemovedFromWantlist, unit, gap_opts)

    %{
      added: added,
      removed: removed,
      total_added: Enum.sum(Enum.map(Analytics.aggregate_events(AddedToWantlist, unit, gap_opts), & &1.count)),
      total_removed: Enum.sum(Enum.map(removed, & &1.count))
    }
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp date_range("30d") do
    to = DateTime.utc_now()
    from = DateTime.add(to, -30, :day)
    {from, to}
  end

  defp date_range("14d") do
    to = DateTime.utc_now()
    {DateTime.add(to, -14, :day), to}
  end

  defp date_range("90d") do
    to = DateTime.utc_now()
    {DateTime.add(to, -90, :day), to}
  end

  defp date_range("3m") do
    to = DateTime.utc_now()
    {DateTime.add(to, -90, :day), to}
  end

  defp date_range("6m") do
    to = DateTime.utc_now()
    {DateTime.add(to, -180, :day), to}
  end

  defp date_range("12m") do
    to = DateTime.utc_now()
    {DateTime.add(to, -365, :day), to}
  end

  defp date_range("all"), do: {nil, nil}

  defp range_unit("14d"), do: :day
  defp range_unit("30d"), do: :day
  defp range_unit("90d"), do: :week
  defp range_unit(_), do: :month

  defp date_opts(nil, nil), do: []
  defp date_opts(from, to), do: [from: from, to: to]

  defp gap_opts(nil, nil, _opts), do: []
  defp gap_opts(_from, _to, opts), do: Keyword.put(opts, :fill_gaps, true)

  # AIDEV-NOTE: Serialize analytics rows to JSON for the AnalyticsChart hook.
  # Grouped rows have a :series key derived from the grouped field value.
  defp period_to_iso(dt) when is_struct(dt, DateTime), do: DateTime.to_iso8601(dt)
  defp period_to_iso(ndt) when is_struct(ndt, NaiveDateTime), do: NaiveDateTime.to_iso8601(ndt)

  defp chart_json(rows, series_field \\ nil) do
    rows
    |> Enum.map(fn row ->
      base = %{
        period: period_to_iso(row.period),
        count: row.count
      }

      if series_field && Map.has_key?(row, series_field) do
        Map.put(base, :series, to_string(Map.get(row, series_field) || "unknown"))
      else
        base
      end
    end)
    |> Jason.encode!()
  end

  # ---------------------------------------------------------------------------
  # Components
  # ---------------------------------------------------------------------------

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :color, :string, default: "gray"

  defp kpi_card(assigns) do
    ~H"""
    <div class={["bg-gray-800 rounded-lg border p-6", kpi_border(@color)]}>
      <p class={["text-3xl font-bold", kpi_text(@color)]}>{@value}</p>
      <p class="text-sm text-gray-400 mt-1">{@label}</p>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :chart_id, :string, required: true
  attr :data, :string, required: true
  attr :unit, :string, default: "month"

  defp chart_card(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg border border-gray-700 p-6">
      <h3 class="text-base font-semibold text-white mb-4">{@title}</h3>
      <div
        id={"chart-#{@chart_id}"}
        phx-hook="AnalyticsChart"
        data-chart-type="bar"
        data-chart-id={@chart_id}
        data-unit={@unit}
        data-inline-data={@data}
        class="h-44 w-full"
      >
      </div>
    </div>
    """
  end

  defp kpi_border("violet"), do: "border-violet-800"
  defp kpi_border("red"), do: "border-red-800"
  defp kpi_border("emerald"), do: "border-emerald-800"
  defp kpi_border("yellow"), do: "border-yellow-800"
  defp kpi_border("orange"), do: "border-orange-800"
  defp kpi_border("sky"), do: "border-sky-800"
  defp kpi_border(_), do: "border-gray-700"

  defp kpi_text("violet"), do: "text-violet-400"
  defp kpi_text("red"), do: "text-red-400"
  defp kpi_text("emerald"), do: "text-emerald-400"
  defp kpi_text("yellow"), do: "text-yellow-400"
  defp kpi_text("orange"), do: "text-orange-400"
  defp kpi_text("sky"), do: "text-sky-400"
  defp kpi_text(_), do: "text-white"
end
