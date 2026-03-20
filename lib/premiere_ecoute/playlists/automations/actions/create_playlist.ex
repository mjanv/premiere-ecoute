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

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.LibraryPlaylist

  @month_names ~w(January February March April May June July August September October November December)

  @impl true
  def id, do: "create_playlist"

  @impl true
  def validate_config(%{"name" => name}) when is_binary(name) and name != "", do: :ok
  def validate_config(_), do: {:error, ["name is required"]}

  @impl true
  def execute(%{"name" => name_template} = config, _context, scope) do
    name = resolve_placeholders(name_template)
    description = Map.get(config, "description", "")
    public = Map.get(config, "public", false)

    playlist = %LibraryPlaylist{
      provider: :spotify,
      title: name,
      description: description,
      public: public
    }

    case Apis.spotify().create_playlist(scope, playlist) do
      {:ok, created} -> {:ok, %{"created_playlist_id" => created.playlist_id, "playlist_name" => created.title}}
      {:error, reason} -> {:error, reason}
    end
  end

  # AIDEV-NOTE: placeholders resolved against the date at execution time, not scheduling time
  defp resolve_placeholders(template) do
    today = Date.utc_today()
    month_idx = today.month - 1
    next_idx = rem(month_idx + 1, 12)
    prev_idx = rem(month_idx + 11, 12)

    template
    |> String.replace("%{month}", Enum.at(@month_names, month_idx))
    |> String.replace("%{next_month}", Enum.at(@month_names, next_idx))
    |> String.replace("%{previous_month}", Enum.at(@month_names, prev_idx))
    |> String.replace("%{year}", to_string(today.year))
  end
end
