defmodule PremiereEcoute.Playlists.Automations.Actions.CreatePlaylist do
  @moduledoc """
  Creates an empty Spotify playlist for the user.

  The `name` config field supports date placeholders that are resolved at
  execution time:

    - `%{month}`          — current month name (e.g. "March")
    - `%{next_month}`     — next month name
    - `%{previous_month}` — previous month name
    - `%{year}`           — current 4-digit year (e.g. "2026")

  The created playlist's Spotify ID is stored in the context under
  `"created_playlist_id"` so subsequent steps can reference it.
  """

  @behaviour PremiereEcoute.Playlists.Automations.Action

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.Automations.Template
  alias PremiereEcoute.Playlists.Services.PlaylistCreation

  @impl true
  def id, do: "create_playlist"

  @impl true
  def validate(%{"name" => name}) when is_binary(name) and name != "", do: :ok
  def validate(_), do: {:error, ["name is required"]}

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
