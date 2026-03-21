defmodule PremiereEcoute.Playlists.Automations.Actions.CopyPlaylist do
  @moduledoc """
  Appends all tracks from a source playlist into a target playlist.

  The `target_playlist_id` field accepts either a literal Spotify playlist ID or
  `"$created_playlist_id"` to reference the playlist created by a preceding
  `create_playlist` step via the pipeline context.
  """

  @behaviour PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Apis

  @impl true
  def id, do: "copy_playlist"

  @impl true
  def validate(%{"source_playlist_id" => src, "target_playlist_id" => tgt})
      when is_binary(src) and src != "" and is_binary(tgt) and tgt != "",
      do: :ok

  def validate(%{"source_playlist_id" => src}) when is_binary(src) and src != "",
    do: {:error, ["target_playlist_id is required"]}

  def validate(%{"target_playlist_id" => tgt}) when is_binary(tgt) and tgt != "",
    do: {:error, ["source_playlist_id is required"]}

  def validate(_), do: {:error, ["source_playlist_id and target_playlist_id are required"]}

  @impl true
  def execute(%{"source_playlist_id" => source_id, "target_playlist_id" => target_id_or_ref}, context, scope) do
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
