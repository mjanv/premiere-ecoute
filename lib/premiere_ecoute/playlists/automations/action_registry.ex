defmodule PremiereEcoute.Playlists.Automations.ActionRegistry do
  @moduledoc """
  Compile-time registry of action modules.

  String keys are derived from each module's `id/0` — no manual string mapping.
  To add a new action: implement `use Action`, then add the module to @modules below.
  """

  # AIDEV-NOTE: only the module list needs updating when adding a new action
  @modules [
    PremiereEcoute.Playlists.Automations.Actions.CopyPlaylist,
    PremiereEcoute.Playlists.Automations.Actions.CreatePlaylist,
    PremiereEcoute.Playlists.Automations.Actions.EmptyPlaylist,
    PremiereEcoute.Playlists.Automations.Actions.MergePlaylists,
    PremiereEcoute.Playlists.Automations.Actions.RemoveDuplicates,
    PremiereEcoute.Playlists.Automations.Actions.ShufflePlaylist,
    PremiereEcoute.Playlists.Automations.Actions.SnapshotPlaylist
  ]

  @actions Map.new(@modules, fn mod -> {mod.id(), mod} end)

  @doc "Returns `{:ok, module}` for a registered action_type, `:error` otherwise."
  @spec get(String.t()) :: {:ok, module()} | :error
  def get(action_type), do: Map.fetch(@actions, action_type)

  @doc "Returns all registered actions as a map of action_type => module."
  @spec all() :: %{String.t() => module()}
  def all, do: @actions

  @doc "Returns metadata for all registered actions, keyed by action_type."
  @spec all_meta() :: %{String.t() => PremiereEcoute.Playlists.Automations.Action.meta()}
  def all_meta, do: Map.new(@modules, fn mod -> {mod.id(), mod.meta()} end)
end
