defmodule PremiereEcoute.Playlists.Automations.ActionRegistry do
  @moduledoc """
  Compile-time registry mapping action_type strings to action modules.

  To add a new action: implement the `Action` behaviour, then add an entry here.
  """

  alias PremiereEcoute.Playlists.Automations.Actions.CopyPlaylist
  alias PremiereEcoute.Playlists.Automations.Actions.CreatePlaylist
  alias PremiereEcoute.Playlists.Automations.Actions.EmptyPlaylist
  alias PremiereEcoute.Playlists.Automations.Actions.MergePlaylists
  alias PremiereEcoute.Playlists.Automations.Actions.RemoveDuplicates
  alias PremiereEcoute.Playlists.Automations.Actions.ShufflePlaylist
  alias PremiereEcoute.Playlists.Automations.Actions.SnapshotPlaylist

  @actions %{
    "copy_playlist" => CopyPlaylist,
    "create_playlist" => CreatePlaylist,
    "empty_playlist" => EmptyPlaylist,
    "merge_playlists" => MergePlaylists,
    "remove_duplicates" => RemoveDuplicates,
    "shuffle_playlist" => ShufflePlaylist,
    "snapshot_playlist" => SnapshotPlaylist
  }

  @doc "Returns `{:ok, module}` for a registered action_type, `:error` otherwise."
  @spec get(String.t()) :: {:ok, module()} | :error
  def get(action_type), do: Map.fetch(@actions, action_type)

  @doc "Returns all registered actions as a map of action_type => module."
  @spec all() :: %{String.t() => module()}
  def all, do: @actions
end
