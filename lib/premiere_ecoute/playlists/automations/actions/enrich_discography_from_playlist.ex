defmodule PremiereEcoute.Playlists.Automations.Actions.EnrichDiscographyFromPlaylist do
  @moduledoc false

  use PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Discography.LibraryPlaylist

  action "enrich_discography_from_playlist" do
    description("Adds missing artists and albums from a library playlist to the discography.")

    inputs do
      input(:playlist, :playlist_id, required: true, description: "Library playlist to enrich from")
    end

    outputs do
      output(:new_artists, :integer, description: "Number of new artists scheduled for enrichment")
      output(:skipped_albums, :integer, description: "Number of albums already in discography")
      output(:skipped, :boolean, description: "True when playlist is unchanged since last run")
    end
  end

  @impl true
  def execute(%{"playlist" => playlist_id}, _context, scope) do
    case LibraryPlaylist.get_by_playlist_id(scope.user, playlist_id) do
      nil ->
        {:error, :playlist_not_found}

      library_playlist ->
        case Discography.sync_playlist(library_playlist) do
          {:ok, :unchanged} -> {:ok, %{"skipped" => true}}
          {:ok, result} -> {:ok, %{"new_artists" => result.new_artists, "skipped_albums" => result.skipped_albums}}
          {:error, _} = error -> error
        end
    end
  end
end
