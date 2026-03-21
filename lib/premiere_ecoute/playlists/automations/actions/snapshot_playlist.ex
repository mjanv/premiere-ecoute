defmodule PremiereEcoute.Playlists.Automations.Actions.SnapshotPlaylist do
  @moduledoc """
  `name` supports Template date placeholders: `%{month}`, `%{next_month}`,
  `%{previous_month}`, `%{year}`.

  Stores `created_playlist_id` in context so subsequent steps can reference it.
  """

  use PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.Automations.Template
  alias PremiereEcoute.Playlists.Services.PlaylistCreation

  action "snapshot_playlist" do
    description("Creates a dated snapshot of a playlist under a new name.")

    inputs do
      input(:source, :playlist_id, required: true, description: "Playlist to snapshot")
      input(:name, :string, required: true, description: "Snapshot name (supports date placeholders)")
      input(:description, :string, required: false, description: "Snapshot playlist description")
      input(:public, :boolean, required: false, description: "Whether the snapshot is public")
    end

    outputs do
      output(:created_playlist_id, :playlist_id, description: "Spotify ID of the created snapshot")
      output(:playlist_name, :string, description: "Resolved name of the snapshot")
      output(:track_count, :integer, description: "Number of tracks copied into the snapshot")
    end
  end

  @impl true
  def execute(%{"source" => source_id, "name" => name_template} = config, _context, scope) do
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
