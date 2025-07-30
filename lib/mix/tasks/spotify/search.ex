defmodule Mix.Tasks.Spotify.Search do
  @moduledoc false

  use Mix.Task
  use Boundary, classify_to: PremiereEcouteMix

  alias PremiereEcoute.Apis.SpotifyApi

  def run(args) do
    Application.ensure_all_started(:req)

    {[query: query], [], []} = OptionParser.parse(args, strict: [query: :string])

    Application.put_env(:premiere_ecoute, :spotify_client_id, System.get_env("SPOTIFY_CLIENT_ID"))
    Application.put_env(:premiere_ecoute, :spotify_client_secret, System.get_env("SPOTIFY_CLIENT_SECRET"))

    case SpotifyApi.search_albums(query) do
      {:ok, albums} ->
        for album <- albums do
          Mix.shell().info("#{album.name} - #{album.artist} (#{album.spotify_id})")
        end

      {:error, reason} ->
        Mix.shell().info("No albums found due to: #{inspect(reason)}")
    end
  end
end
