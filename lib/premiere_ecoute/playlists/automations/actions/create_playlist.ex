defmodule PremiereEcoute.Playlists.Automations.Actions.CreatePlaylist do
  @moduledoc """
  The `name` field supports date placeholders: `%{month}`, `%{next_month}`,
  `%{previous_month}`, `%{year}`, resolved at execution time.

  Stores `created_playlist_id` in context so subsequent steps can reference it.
  """

  use PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.Automations.Template
  alias PremiereEcoute.Playlists.Services.PlaylistCreation

  action "create_playlist" do
    description("Creates an empty Spotify playlist for the user.")

    inputs do
      input(:name, :string, required: true, description: "Playlist name (supports date placeholders)")
      input(:description, :string, required: false, description: "Playlist description")
      input(:public, :boolean, required: false, description: "Whether the playlist is public")
    end

    outputs do
      output(:created_playlist_id, :playlist_id, description: "Spotify ID of the created playlist")
      output(:playlist_name, :string, description: "Resolved name of the created playlist")
    end
  end

  @impl true
  def execute(%{"name" => name_template} = config, _context, scope) do
    name = Template.resolve(name_template)
    description = Map.get(config, "description", "")
    public = Map.get(config, "public", false)

    playlist = %LibraryPlaylist{
      provider: :spotify,
      title: name,
      description: description,
      public: public
    }

    case PlaylistCreation.create_library_playlist(scope, playlist) do
      {:ok, created} -> {:ok, %{"created_playlist_id" => created.playlist_id, "playlist_name" => created.title}}
      {:error, reason} -> {:error, reason}
    end
  end
end
