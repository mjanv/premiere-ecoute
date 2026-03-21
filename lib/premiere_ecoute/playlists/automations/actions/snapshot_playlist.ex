defmodule PremiereEcoute.Playlists.Automations.Actions.SnapshotPlaylist do
  @moduledoc """
  Creates a dated snapshot of a playlist.

  Creates a new Spotify playlist with the given name (supports Template date
  placeholders) and copies all tracks from the source playlist into it.

  The created playlist's Spotify ID is stored in context under
  `"created_playlist_id"` so subsequent steps can reference it.

  Supported name placeholders (resolved at execution time):

    - `%{month}`          — current month name (e.g. "March")
    - `%{next_month}`     — next month name
    - `%{previous_month}` — previous month name
    - `%{year}`           — current 4-digit year (e.g. "2026")
  """

  @behaviour PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.Automations.Template
  alias PremiereEcoute.Playlists.Services.PlaylistCreation

  @impl true
  def id, do: "snapshot_playlist"

  @impl true
  def validate(%{"source_playlist_id" => src, "name" => name})
      when is_binary(src) and src != "" and is_binary(name) and name != "",
      do: :ok

  def validate(%{"source_playlist_id" => src}) when is_binary(src) and src != "",
    do: {:error, ["name is required"]}

  def validate(%{"name" => name}) when is_binary(name) and name != "",
    do: {:error, ["source_playlist_id is required"]}

  def validate(_), do: {:error, ["source_playlist_id and name are required"]}

  @impl true
  def execute(%{"source_playlist_id" => source_id, "name" => name_template} = config, _context, scope) do
    name = Template.resolve(name_template)
    description = Map.get(config, "description", "")
    public = Map.get(config, "public", false)

    playlist = %LibraryPlaylist{provider: :spotify, title: name, description: description, public: public}

    with {:ok, created} <- PlaylistCreation.create_library_playlist(scope, playlist),
         {:ok, source} <- Apis.spotify().get_playlist(source_id),
         {:ok, _} <- Apis.spotify().add_items_to_playlist(scope, created.playlist_id, source.tracks) do
      {:ok,
       %{"created_playlist_id" => created.playlist_id, "playlist_name" => created.title, "track_count" => length(source.tracks)}}
    end
  end
end
