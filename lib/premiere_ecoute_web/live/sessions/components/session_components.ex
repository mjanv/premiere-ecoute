defmodule PremiereEcouteWeb.Sessions.Components.SessionComponents do
  @moduledoc """
  Listening session UI components.

  Provides reusable Phoenix components for displaying session details including source information (album/playlist), statistics, voting interface, vote distribution graphs, progress tracking, and visibility controls.
  """

  use Phoenix.Component
  use Gettext, backend: PremiereEcoute.Gettext

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession

  def source_details(%{listening_session: %{source: :album, album: album}} = assigns) do
    assigns = assign(assigns, :album, album)

    ~H"""
    <div class="flex items-center justify-end space-x-4">
      <!-- Album Info -->
      <div class="text-right">
        <div class="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span class="text-purple-200 block">{gettext("Artist")}</span>
            <span class="font-medium text-white">{@album.artist}</span>
          </div>
          <div>
            <span class="text-purple-200 block">{gettext("Released")}</span>
            <span class="font-medium text-white">{PremiereEcouteCore.Date.date(@album.release_date)}</span>
          </div>
          <div>
            <span class="text-purple-200 block">{gettext("Tracks")}</span>
            <span class="font-medium text-white">{@album.total_tracks}</span>
          </div>
          <div>
            <span class="text-purple-200 block">{gettext("Duration")}</span>
            <span class="font-medium text-white">{PremiereEcouteCore.Duration.duration(Album.total_duration(@album))}</span>
          </div>
        </div>
      </div>
      
    <!-- Album Cover -->
      <div class="flex-shrink-0">
        <%= if @album.cover_url do %>
          <img
            src={@album.cover_url}
            alt={"#{@album.name} cover"}
            class="w-32 h-32 rounded-lg shadow-lg"
          />
        <% else %>
          <div class="w-32 h-32 bg-white/20 rounded-lg flex items-center justify-center">
            <svg class="w-10 h-10 text-white" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" />
            </svg>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def source_details(%{listening_session: %{source: :playlist, playlist: playlist}} = assigns) do
    assigns = assign(assigns, :playlist, playlist)

    ~H"""
    <div class="flex items-center justify-end space-x-4">
      <!-- Playlist Info -->
      <div class="text-right">
        <div class="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span class="text-purple-200 block">{gettext("Owner")}</span>
            <span class="font-medium text-white">{@playlist.owner_name}</span>
          </div>
          <div>
            <span class="text-purple-200 block">{gettext("Provider")}</span>
            <span class="font-medium text-white">
              {String.capitalize(to_string(@playlist.provider))}
            </span>
          </div>
          <div>
            <span class="text-purple-200 block">{gettext("Tracks")}</span>
            <span class="font-medium text-white">{length(@playlist.tracks || [])}</span>
          </div>
          <div>
            <span class="text-purple-200 block">{gettext("Public")}</span>
            <span class="font-medium text-white">
              {if @playlist.public, do: gettext("Yes"), else: gettext("No")}
            </span>
          </div>
        </div>
      </div>
      
    <!-- Playlist Cover -->
      <div class="flex-shrink-0">
        <%= if @playlist.cover_url do %>
          <img
            src={@playlist.cover_url}
            alt={"#{@playlist.title} cover"}
            class="w-32 h-32 rounded-lg shadow-lg"
          />
        <% else %>
          <div class="w-32 h-32 bg-white/20 rounded-lg flex items-center justify-center">
            <svg class="w-10 h-10 text-white" fill="currentColor" viewBox="0 0 24 24">
              <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :report, :any, required: true
  attr :key, :string, required: true
  attr :legend, :string, required: true
  attr :base, :string, required: false, default: nil
  attr :show, :boolean, required: false, default: true

  def session_stat(assigns) do
    ~H"""
    <%= if @show do %>
      <div class="text-center bg-white/20 rounded-lg p-3">
        <div class="text-2xl font-bold text-white">
          <.async_result :let={report} assign={@report}>
            <:loading>--</:loading>
            <:failed>--</:failed>
            <%= case session_average_score2(report, @key) do %>
              <% score when is_number(score) -> %>
                {score}

                <%= if @base do %>
                  <span class="text-lg text-purple-200">/{@base}</span>
                <% end %>
              <% score when is_binary(score) -> %>
                {score}
            <% end %>
          </.async_result>
        </div>
        <div class="text-xs text-purple-200 font-medium">{@legend}</div>
      </div>
    <% end %>
    """
  end

  def session_average_score2(nil, _), do: "-"

  def session_average_score2(%{session_summary: summary}, key) do
    case summary[key] do
      nil -> "-"
      score -> score
    end
  end

  attr :checked, :boolean, required: true
  attr :legend, :string, required: true
  attr :rest, :global

  def session_toggle(assigns) do
    ~H"""
    <div class="flex items-center">
      <label class="flex items-center cursor-pointer">
        <input type="checkbox" {@rest} checked={@checked} class="sr-only" />
        <div class={[
          "relative inline-flex h-5 w-9 rounded-full transition-colors duration-200 ease-in-out mr-3",
          if(@checked, do: "bg-purple-500", else: "bg-white/20")
        ]}>
          <span class={[
            "inline-block h-4 w-4 transform rounded-full bg-white shadow-md transition duration-200 ease-in-out translate-y-0.5",
            if(@checked, do: "translate-x-4", else: "translate-x-0.5")
          ]}>
          </span>
        </div>
        <span class="text-purple-200 text-sm font-medium">
          {gettext("Display votes")}
        </span>
      </label>
    </div>
    """
  end

  attr :value, :integer, required: true
  attr :at, :any, required: true
  attr :rest, :global

  def next_track(assigns) do
    ~H"""
    <div class="pt-2">
      <%= if @at do %>
        <!-- Active Timer - replaces slider when countdown is active -->
        <div class="flex items-center justify-center space-x-2">
          <span class="text-purple-200 text-xs font-medium">
            {gettext("Next track in")}
          </span>
          <div
            id="next-track-timer"
            phx-hook="NextTrackTimer"
            data-next-track-at={DateTime.to_iso8601(@at)}
            class="bg-purple-600/20 px-2 py-1 rounded border border-purple-500/30"
          >
            <span class="font-mono text-sm font-bold text-purple-300" id="timer-display">
              --:--
            </span>
          </div>
        </div>
      <% else %>
        <!-- Slider - shown when no timer is active -->
        <div class="flex items-center space-x-4">
          <span class="text-purple-200 text-sm font-medium whitespace-nowrap">
            {gettext("Next track in")}
          </span>
          <div class="flex-1 px-1 relative">
            <form phx-change="update_next_track">
              <input
                type="range"
                name="next_track"
                min="0"
                max="60"
                value={@value}
                id="next-track-slider"
                class="w-full h-2 rounded-lg appearance-none cursor-pointer bg-white/20 slider-purple"
                phx-debounce="300"
              />
            </form>
            <style>
              .slider-purple::-webkit-slider-thumb {
                appearance: none;
                width: 16px;
                height: 16px;
                border-radius: 50%;
                background: #8b5cf6;
                cursor: pointer;
                border: 2px solid white;
                box-shadow: 0 2px 6px rgba(0,0,0,0.2);
              }
              .slider-purple::-moz-range-thumb {
                width: 16px;
                height: 16px;
                border-radius: 50%;
                background: #8b5cf6;
                cursor: pointer;
                border: 2px solid white;
                box-shadow: 0 2px 6px rgba(0,0,0,0.2);
              }
              .slider-purple::-webkit-slider-track {
                height: 8px;
                border-radius: 4px;
                background: linear-gradient(to right, #8b5cf6 0%, #8b5cf6 {(@show[:next_track] / 60) * 100}%, rgba(255,255,255,0.2) {(@show[:next_track] / 60) * 100}%, rgba(255,255,255,0.2) 100%);
              }
            </style>
          </div>
          <span class={[
            "text-sm font-medium min-w-[60px] text-center",
            if(@value == 0, do: "text-gray-400", else: "text-white")
          ]}>
            <%= if @value == 0 do %>
              {gettext("Off")}
            <% else %>
              {@value}s
            <% end %>
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  attr :listening_session, :any, required: true
  attr :user_current_rating, :string, required: true
  attr :open_vote, :boolean, required: true

  def vote_bar(assigns) do
    ~H"""
    <%= if @listening_session.status == :active do %>
      <div class="rounded-xl p-3 mb-6 bg-purple-900/20">
        <div class="flex items-center justify-center space-x-3">
          <span class="text-s text-white-300 whitespace-nowrap">
            {gettext("Your rating")}
          </span>
          <div class="flex space-x-1">
            <%= for rating <- @listening_session.vote_options do %>
              <button
                phx-click="vote_track"
                phx-value-rating={rating}
                disabled={not @open_vote}
                class={[
                  "px-2 py-1 text-sm rounded border transition-colors min-w-[32px]",
                  if(ListeningSession.playing?(@listening_session),
                    do: [
                      "bg-gray-700 border-gray-600 text-gray-300 hover:bg-purple-500/20 hover:border-purple-400 hover:text-purple-300",
                      if(@user_current_rating == rating, do: "bg-purple-600 border-purple-500 text-white", else: "")
                    ],
                    else: "bg-gray-800 border-gray-700 text-gray-600 cursor-not-allowed opacity-50"
                  )
                ]}
                disabled={!ListeningSession.playing?(@listening_session)}
              >
                {rating}
              </button>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  attr :listening_session, :any, required: true
  attr :trends, :any, required: true
  attr :class, :string, default: ""

  def note_graph(assigns) do
    ~H"""
    <.async_result :let={trends} assign={@trends}>
      <:loading>
        <div class="flex items-center justify-center h-[150px] text-sm text-gray-400">
          Loading trends…
        </div>
      </:loading>

      <:failed>
        <div class="flex items-center justify-center h-[150px] text-sm text-red-400">
          Could not load vote trends.
        </div>
      </:failed>

      <div
        id="note-graph"
        phx-hook="NoteGraph"
        data-vote-data={Jason.encode!(Enum.map(trends, fn {timestamp, avg} -> [timestamp, avg] end))}
        data-vote-options={Jason.encode!(@listening_session.vote_options)}
        data-session-start={Jason.encode!(@listening_session.started_at)}
        class={["rounded-lg pt-4 pr-4 pl-4", @class]}
      >
        <div style="position: relative; height: 150px; width: 100%;">
          <canvas id="note-graph-canvas"></canvas>
        </div>
      </div>
    </.async_result>
    """
  end

  def distribution_graph(assigns) do
    ~H"""
    <.async_result :let={report} assign={@report}>
      <:loading>
        <%= for rating <- @listening_session.vote_options do %>
          <div class="flex-1 flex flex-col items-center px-1">
            <div class="w-full bg-gray-600 rounded-t animate-pulse" style="height: 8px"></div>
            <span class="text-xs text-gray-400 font-medium mt-1">
              {rating}
            </span>
          </div>
        <% end %>
      </:loading>
      <:failed></:failed>
      <% distribution = track_vote_distribution(@track.id, report, @listening_session) %>
      <% track_max_votes = distribution |> Enum.map(&elem(&1, 1)) |> Enum.max() %>
      <%= for {rating, votes} <- distribution do %>
        <div class="flex-1 flex flex-col items-center px-1 min-w-0">
          <div
            class={[
              "w-full rounded-t transition-all duration-300 min-w-0 relative flex items-center justify-center",
              vote_option_color(rating, @listening_session)
            ]}
            style={"height: #{bar_height(votes, track_max_votes, 110, 15)}px"}
          >
            <span class="text-sm font-medium text-white">{Integer.to_string(votes)}</span>
          </div>

          <span class="text-xs text-gray-400 font-medium mt-1">{rating}</span>
        </div>
      <% end %>
    </.async_result>
    """
  end

  def track_vote_distribution(_track_id, nil, session),
    do: for(rating <- session.vote_options, do: {rating, 0})

  def track_vote_distribution(track_id, report, session) do
    distribution =
      report.votes
      |> Enum.filter(&(&1.track_id == track_id))
      |> Enum.group_by(& &1.value)
      |> Map.new(fn {value, votes} -> {value, length(votes)} end)

    for rating <- session.vote_options do
      {rating, Map.get(distribution, rating, 0)}
    end
  end

  defp bar_height(votes, max_votes, container_height, min_height) do
    cond do
      votes == 0 -> min_height
      max_votes == 0 -> min_height
      true -> max(round(votes * container_height * 0.85 / max_votes), min_height)
    end
  end

  def vote_option_color(vote_option, session) do
    index = Enum.find_index(session.vote_options, &(&1 == vote_option)) || 0

    cond do
      vote_option == "smash" ->
        "bg-green-500"

      vote_option == "pass" ->
        "bg-red-500"

      true ->
        colors = [
          "bg-red-500",
          "bg-orange-500",
          "bg-yellow-500",
          "bg-green-500",
          "bg-blue-500",
          "bg-purple-500",
          "bg-pink-500",
          "bg-indigo-500"
        ]

        Enum.at(colors, rem(index, length(colors)), "bg-gray-500")
    end
  end

  def session_track_stat(assigns) do
    ~H"""
    <div class="text-center">
      <p class={"text-xl font-bold text-#{@color}-300"}>
        <.async_result :let={report} assign={@report}>
          <:loading>-</:loading>
          <:failed>-</:failed>
          <%= case track_score(@track.id, report, @key) do %>
            <% "N/A" -> %>
              -
            <% score -> %>
              {score}
          <% end %>
        </.async_result>
      </p>
      <p class={"text-#{@color}-400/70"}>{@legend}</p>
    </div>
    """
  end

  def track_score(_track_id, nil, _), do: "-"

  def track_score(track_id, report, key) do
    case Enum.find(report.track_summaries, &(&1["track_id"] == track_id)) do
      nil -> "-"
      track_summary -> Map.get(track_summary, key, "-")
    end
  end

  attr :current_visibility, :atom, required: true
  attr :visibility_options, :list, required: true

  def visibility_dropdown(assigns) do
    ~H"""
    <div class="relative" id="visibility-dropdown" phx-hook="VisibilityDropdown">
      <!-- Selected option display / Dropdown trigger -->
      <button
        type="button"
        id="visibility-dropdown-button"
        class="w-full bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 flex items-center justify-between"
      >
        <div class="flex items-center space-x-2">
          <.visibility_icon_svg visibility={@current_visibility} />
          <span>{visibility_label(@current_visibility)}</span>
        </div>
        <svg class="w-4 h-4 transition-transform" id="dropdown-chevron" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      
    <!-- Dropdown menu -->
      <div
        id="visibility-dropdown-menu"
        class="hidden absolute z-10 w-full mt-2 bg-gray-800 border border-white/20 rounded-lg shadow-lg overflow-hidden"
      >
        <%= for %{value: value, label: label, description: description} <- @visibility_options do %>
          <button
            type="button"
            phx-click="update_visibility"
            phx-value-visibility={Atom.to_string(value)}
            class={[
              "w-full text-left px-4 py-3 hover:bg-white/10 transition-colors border-b border-white/10 last:border-b-0",
              if(@current_visibility == value, do: "bg-purple-600/20", else: "")
            ]}
          >
            <div class="flex items-start space-x-3">
              <div class="flex-shrink-0 mt-0.5">
                <.visibility_icon_svg visibility={value} />
              </div>
              <div class="flex-1 min-w-0">
                <div class="text-sm font-medium text-white">
                  {label}
                </div>
                <div class="text-xs text-purple-300/70 mt-1">
                  {description}
                </div>
              </div>
              <%= if @current_visibility == value do %>
                <svg class="w-5 h-5 text-purple-400 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                    clip-rule="evenodd"
                  />
                </svg>
              <% end %>
            </div>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  attr :visibility, :atom, required: true

  defp visibility_icon_svg(%{visibility: :private} = assigns) do
    ~H"""
    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
      />
    </svg>
    """
  end

  defp visibility_icon_svg(%{visibility: :protected} = assigns) do
    ~H"""
    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
      />
    </svg>
    """
  end

  defp visibility_icon_svg(%{visibility: :public} = assigns) do
    ~H"""
    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
    """
  end

  defp visibility_label(:private), do: "Private"
  defp visibility_label(:protected), do: "Protected"
  defp visibility_label(:public), do: "Public"
end
