defmodule PremiereEcoute.Playlists.Automations.Actions.CopyPlaylist do
  @moduledoc """
  `target` accepts a literal Spotify ID or `"$created_playlist_id"` to reference
  the playlist created by a preceding `create_playlist` step.
  """

  use PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Apis

  action "copy_playlist" do
    description("Appends all tracks from a source playlist into a target playlist.")

    inputs do
      input(:source, :playlist_id, required: true, description: "Playlist to copy from")
      input(:target, :playlist_id, required: true, description: "Playlist to copy into (or $created_playlist_id)")
    end

    outputs do
      output(:copied_count, :integer, description: "Number of tracks copied")
    end
  end

  @impl true
  def execute(%{"source" => source_id, "target" => target_id_or_ref}, context, scope) do
    target_id = resolve_id(target_id_or_ref, context)

    with {:ok, source} <- Apis.spotify().get_playlist(source_id),
         {:ok, _} <- Apis.spotify().add_items_to_playlist(scope, target_id, source.tracks) do
      {:ok, %{copied_count: length(source.tracks)}}
    end
  end

  # AIDEV-NOTE: "$created_playlist_id" pulls the ID set by a preceding create_playlist step
  defp resolve_id("$created_playlist_id", %{"created_playlist_id" => id}), do: id
  defp resolve_id(literal, _context), do: literal
end
