defmodule PremiereEcouteWeb.Playlists.Automations.Components.AutomationComponents do
  @moduledoc "Reusable components for automation UI: step builder, run history, schedule summary."

  use Phoenix.Component
  use Gettext, backend: PremiereEcoute.Gettext

  # ---------------------------------------------------------------------------
  # Schedule summary
  # ---------------------------------------------------------------------------

  @doc "Human-readable one-liner for an automation's schedule."
  attr :automation, :map, required: true

  def schedule_summary(assigns) do
    ~H"""
    <span>
      <%= case @automation.schedule do %>
        <% :manual -> %>
          {gettext("Manual")}
        <% :once -> %>
          <%= if @automation.scheduled_at do %>
            {gettext("Once at %{dt}", dt: format_datetime(@automation.scheduled_at))}
          <% else %>
            {gettext("Once (not scheduled)")}
          <% end %>
        <% :recurring -> %>
          {cron_label(@automation.cron_expression)}
        <% _ -> %>
          —
      <% end %>
    </span>
    """
  end

  # ---------------------------------------------------------------------------
  # Step list (read-only)
  # ---------------------------------------------------------------------------

  @doc "Read-only ordered list of automation steps."
  attr :steps, :list, required: true
  attr :registry, :map, required: true

  def steps_list(assigns) do
    ~H"""
    <div class="space-y-2">
      <%= if Enum.empty?(@steps) do %>
        <p class="text-sm text-gray-500 italic">{gettext("No steps configured.")}</p>
      <% else %>
        <%= for step <- Enum.sort_by(@steps, & &1["position"]) do %>
          <div class="flex items-center gap-3 p-3 bg-gray-800/60 rounded-lg border border-gray-700">
            <span class="flex-shrink-0 w-6 h-6 rounded-full bg-purple-700 text-white text-xs font-bold flex items-center justify-center">
              {step["position"]}
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-white">{action_label(step["action_type"], @registry)}</p>
              <p class="text-xs text-gray-400 truncate">{config_summary(step["config"])}</p>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Run history row
  # ---------------------------------------------------------------------------

  @doc "A single run history row with expandable step results."
  attr :run, :map, required: true
  attr :expanded, :boolean, default: false
  attr :on_toggle, :string, default: nil

  def run_row(assigns) do
    ~H"""
    <div class="border border-gray-700 rounded-lg overflow-hidden">
      <div
        class="flex items-center gap-4 p-4 bg-gray-800/40 cursor-pointer hover:bg-gray-800/70 transition-colors"
        phx-click={@on_toggle}
        phx-value-run-id={@run.id}
      >
        <div class="flex-1 grid grid-cols-4 gap-4 text-sm">
          <span class="text-gray-400">{trigger_label(@run.trigger)}</span>
          <span><.run_status_badge status={@run.status} /></span>
          <span class="text-gray-300">{format_datetime(@run.started_at)}</span>
          <span class="text-gray-400">{run_duration(@run)}</span>
        </div>
        <svg
          class={"w-4 h-4 text-gray-400 transition-transform #{if @expanded, do: "rotate-180"}"}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </div>
      <%= if @expanded do %>
        <div class="border-t border-gray-700 bg-gray-900/30 p-4 space-y-2">
          <%= for step_result <- Enum.sort_by(@run.steps, & &1["position"]) do %>
            <.step_result_row result={step_result} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :status, :atom, required: true

  def run_status_badge(assigns) do
    ~H"""
    <span class={"inline-flex items-center px-2 py-0.5 rounded text-xs font-medium #{status_class(@status)}"}>
      {status_label(@status)}
    </span>
    """
  end

  attr :result, :map, required: true

  def step_result_row(assigns) do
    ~H"""
    <div class={"flex items-start gap-3 p-2 rounded #{step_result_bg(@result["status"])}"}>
      <span class="flex-shrink-0 w-5 h-5 rounded-full bg-gray-700 text-white text-xs font-bold flex items-center justify-center mt-0.5">
        {@result["position"]}
      </span>
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2">
          <span class="text-sm font-medium text-white">{@result["action_type"]}</span>
          <span class={"text-xs px-1.5 py-0.5 rounded #{step_status_class(@result["status"])}"}>{@result["status"]}</span>
        </div>
        <%= if @result["output"] && map_size(@result["output"]) > 0 do %>
          <p class="text-xs text-gray-400 mt-0.5">{output_summary(@result["output"])}</p>
        <% end %>
        <%= if @result["error"] do %>
          <p class="text-xs text-red-400 mt-0.5">{@result["error"]}</p>
        <% end %>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Step builder (used in form)
  # ---------------------------------------------------------------------------

  @doc "Editable step list for the automation form."
  attr :steps, :list, required: true
  attr :registry, :map, required: true
  attr :library_playlists, :list, required: true
  attr :show_picker, :boolean, default: false

  def step_builder(assigns) do
    ~H"""
    <div class="space-y-3" id="step-builder">
      <%= for {step, idx} <- Enum.with_index(@steps) do %>
        <div class="p-4 bg-gray-800/60 rounded-lg border border-gray-700" id={"step-#{idx}"}>
          <div class="flex items-center gap-3 mb-3">
            <span class="flex-shrink-0 w-6 h-6 rounded-full bg-purple-700 text-white text-xs font-bold flex items-center justify-center">
              {step["position"]}
            </span>
            <span class="flex-1 text-sm font-medium text-white">{action_label(step["action_type"], @registry)}</span>
            <div class="flex gap-1">
              <button
                type="button"
                phx-click="move_step_up"
                phx-value-index={idx}
                class="p-1 text-gray-400 hover:text-white disabled:opacity-30"
                disabled={idx == 0}
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                </svg>
              </button>
              <button
                type="button"
                phx-click="move_step_down"
                phx-value-index={idx}
                class="p-1 text-gray-400 hover:text-white disabled:opacity-30"
                disabled={idx == length(@steps) - 1}
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                </svg>
              </button>
              <button
                type="button"
                phx-click="remove_step"
                phx-value-index={idx}
                class="p-1 text-red-400 hover:text-red-300"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>
          <.step_config_fields step={step} index={idx} library_playlists={@library_playlists} />
        </div>
      <% end %>

      <%= if @show_picker do %>
        <div class="border border-gray-600 rounded-lg overflow-hidden">
          <%= for {action_type, _mod} <- @registry do %>
            <button
              type="button"
              phx-click="add_step"
              phx-value-action_type={action_type}
              class="w-full px-4 py-2.5 bg-gray-800 hover:bg-gray-700 text-white text-sm text-left transition-colors border-b border-gray-700 last:border-0"
            >
              {humanize_action(action_type)}
            </button>
          <% end %>
        </div>
      <% else %>
        <button
          type="button"
          phx-click="show_add_step"
          class="w-full py-3 border-2 border-dashed border-gray-600 hover:border-purple-500 text-gray-400 hover:text-purple-400 rounded-lg transition-colors text-sm font-medium flex items-center justify-center gap-2"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
          </svg>
          {gettext("Add step")}
        </button>
      <% end %>
    </div>
    """
  end

  attr :step, :map, required: true
  attr :index, :integer, required: true
  attr :library_playlists, :list, required: true

  def step_config_fields(%{step: %{"action_type" => "create_playlist"}} = assigns) do
    ~H"""
    <div class="space-y-2">
      <div>
        <label class="block text-xs text-gray-400 mb-1">{gettext("Playlist name")}</label>
        <input
          type="text"
          name={"steps[#{@index}][config][name]"}
          value={get_in(@step, ["config", "name"]) || ""}
          class="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm focus:border-purple-500 focus:outline-none"
          placeholder="e.g. Discoveries %{month} %{year}"
        />
        <p class="text-xs text-gray-500 mt-1">{"Available: %{month}, %{next_month}, %{previous_month}, %{year}"}</p>
      </div>
    </div>
    """
  end

  def step_config_fields(%{step: %{"action_type" => "empty_playlist"}} = assigns) do
    ~H"""
    <div class="space-y-2">
      <.playlist_select
        name={"steps[#{@index}][config][playlist_id]"}
        label={gettext("Playlist to empty")}
        value={get_in(@step, ["config", "playlist_id"])}
        playlists={@library_playlists}
      />
    </div>
    """
  end

  def step_config_fields(%{step: %{"action_type" => "remove_duplicates"}} = assigns) do
    ~H"""
    <div class="space-y-2">
      <.playlist_select
        name={"steps[#{@index}][config][playlist_id]"}
        label={gettext("Playlist to deduplicate")}
        value={get_in(@step, ["config", "playlist_id"])}
        playlists={@library_playlists}
      />
    </div>
    """
  end

  def step_config_fields(%{step: %{"action_type" => "shuffle_playlist"}} = assigns) do
    ~H"""
    <div class="space-y-2">
      <.playlist_select
        name={"steps[#{@index}][config][playlist_id]"}
        label={gettext("Playlist to shuffle")}
        value={get_in(@step, ["config", "playlist_id"])}
        playlists={@library_playlists}
      />
    </div>
    """
  end

  def step_config_fields(%{step: %{"action_type" => "copy_playlist"}} = assigns) do
    ~H"""
    <div class="space-y-2">
      <.playlist_select
        name={"steps[#{@index}][config][source_playlist_id]"}
        label={gettext("Source playlist")}
        value={get_in(@step, ["config", "source_playlist_id"])}
        playlists={@library_playlists}
      />
      <.playlist_select
        name={"steps[#{@index}][config][target_playlist_id]"}
        label={gettext("Target playlist")}
        value={get_in(@step, ["config", "target_playlist_id"])}
        playlists={@library_playlists}
      />
    </div>
    """
  end

  def step_config_fields(%{step: %{"action_type" => "merge_playlists"}} = assigns) do
    ~H"""
    <div class="space-y-2">
      <div>
        <label class="block text-xs text-gray-400 mb-1">{gettext("Source playlist IDs (one per line)")}</label>
        <textarea
          name={"steps[#{@index}][config][source_playlist_ids]"}
          rows="3"
          class="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm focus:border-purple-500 focus:outline-none font-mono"
          placeholder="4hnx...&#10;7kzp..."
        >{get_in(@step, ["config", "source_playlist_ids"]) |> List.wrap() |> Enum.join("\n")}</textarea>
      </div>
      <.playlist_select
        name={"steps[#{@index}][config][target_playlist_id]"}
        label={gettext("Target playlist")}
        value={get_in(@step, ["config", "target_playlist_id"])}
        playlists={@library_playlists}
      />
    </div>
    """
  end

  def step_config_fields(%{step: %{"action_type" => "snapshot_playlist"}} = assigns) do
    ~H"""
    <div class="space-y-2">
      <.playlist_select
        name={"steps[#{@index}][config][source_playlist_id]"}
        label={gettext("Playlist to snapshot")}
        value={get_in(@step, ["config", "source_playlist_id"])}
        playlists={@library_playlists}
      />
      <div>
        <label class="block text-xs text-gray-400 mb-1">{gettext("Snapshot name")}</label>
        <input
          type="text"
          name={"steps[#{@index}][config][name]"}
          value={get_in(@step, ["config", "name"]) || ""}
          class="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm focus:border-purple-500 focus:outline-none"
          placeholder="e.g. Archive %{month} %{year}"
        />
        <p class="text-xs text-gray-500 mt-1">{"Available: %{month}, %{next_month}, %{previous_month}, %{year}"}</p>
      </div>
    </div>
    """
  end

  def step_config_fields(assigns) do
    ~H"""
    <p class="text-xs text-gray-500 italic">{gettext("Unknown action type: %{type}", type: @step["action_type"])}</p>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, default: nil
  attr :playlists, :list, required: true

  def playlist_select(assigns) do
    ~H"""
    <div>
      <label class="block text-xs text-gray-400 mb-1">{@label}</label>
      <select
        name={@name}
        class="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm focus:border-purple-500 focus:ring-1 focus:ring-purple-500 focus:outline-none"
      >
        <option value="">{gettext("Select a playlist…")}</option>
        <%= for pl <- @playlists do %>
          <option value={pl.playlist_id} selected={@value == pl.playlist_id}>
            {pl.title}
          </option>
        <% end %>
      </select>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Helpers (private)
  # ---------------------------------------------------------------------------

  defp action_label(action_type, registry) do
    case Map.get(registry, action_type) do
      nil -> action_type
      _mod -> humanize_action(action_type)
    end
  end

  defp humanize_action("copy_playlist"), do: gettext("Copy playlist")
  defp humanize_action("create_playlist"), do: gettext("Create playlist")
  defp humanize_action("empty_playlist"), do: gettext("Empty playlist")
  defp humanize_action("merge_playlists"), do: gettext("Merge playlists")
  defp humanize_action("remove_duplicates"), do: gettext("Remove duplicates")
  defp humanize_action("shuffle_playlist"), do: gettext("Shuffle playlist")
  defp humanize_action("snapshot_playlist"), do: gettext("Snapshot playlist")
  defp humanize_action(other), do: other

  defp config_summary(nil), do: ""

  defp config_summary(config) do
    Enum.map_join(config, ", ", fn {k, v} -> "#{k}: #{v}" end)
  end

  defp cron_label(nil), do: gettext("Recurring")
  defp cron_label(expr), do: gettext("Recurring (%{expr})", expr: expr)

  defp format_datetime(nil), do: "—"
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y %H:%M")
  defp format_datetime(_), do: "—"

  defp trigger_label(:manual), do: gettext("Manual")
  defp trigger_label(:scheduled), do: gettext("Scheduled")
  defp trigger_label(_), do: "—"

  defp status_label(:completed), do: gettext("Completed")
  defp status_label(:failed), do: gettext("Failed")
  defp status_label(:running), do: gettext("Running")
  defp status_label(_), do: "—"

  defp status_class(:completed), do: "bg-green-900/60 text-green-300"
  defp status_class(:failed), do: "bg-red-900/60 text-red-300"
  defp status_class(:running), do: "bg-yellow-900/60 text-yellow-300"
  defp status_class(_), do: "bg-gray-700 text-gray-300"

  defp step_status_class("completed"), do: "bg-green-900/60 text-green-300"
  defp step_status_class("failed"), do: "bg-red-900/60 text-red-300"
  defp step_status_class("skipped"), do: "bg-gray-700 text-gray-500"
  defp step_status_class(_), do: "bg-gray-700 text-gray-300"

  defp step_result_bg("failed"), do: "bg-red-950/30"
  defp step_result_bg("skipped"), do: "opacity-50"
  defp step_result_bg(_), do: ""

  defp run_duration(%{started_at: nil}), do: "—"
  defp run_duration(%{finished_at: nil}), do: gettext("Running…")

  defp run_duration(%{started_at: s, finished_at: f}) do
    diff = DateTime.diff(f, s, :second)
    gettext("%{s}s", s: diff)
  end

  defp output_summary(%{"removed_count" => n}), do: gettext("Removed %{n} tracks", n: n)
  defp output_summary(%{"copied_count" => n}), do: gettext("Copied %{n} tracks", n: n)
  defp output_summary(%{"merged_count" => n}), do: gettext("Merged %{n} tracks", n: n)
  defp output_summary(%{"track_count" => n}), do: gettext("%{n} tracks", n: n)
  defp output_summary(map), do: Enum.map_join(map, ", ", fn {k, v} -> "#{k}: #{v}" end)
end
