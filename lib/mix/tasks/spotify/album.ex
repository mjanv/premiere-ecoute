defmodule Mix.Tasks.Spotify.Album do
  @moduledoc false

  use Mix.Task

  alias PremiereEcoute.Apis.SpotifyApi

  def run(args) do
    Application.ensure_all_started(:req)

    {[id: id], [], []} = OptionParser.parse(args, strict: [id: :string])

    Application.put_env(:premiere_ecoute, :spotify_client_id, System.get_env("SPOTIFY_CLIENT_ID"))
    Application.put_env(:premiere_ecoute, :spotify_client_secret, System.get_env("SPOTIFY_CLIENT_SECRET"))

    case SpotifyApi.get_album(id) do
      {:ok, album} ->
        album = %{clean(album) | tracks: Enum.map(album.tracks, &clean(&1, [:album_id, :album]))}
        Mix.shell().info("#{inspect(album, pretty: true)}")

      {:error, reason} ->
        Mix.shell().info("No album found due to: #{inspect(reason)}")
    end
  end

  defp clean(struct, attrs \\ []) do
    struct |> Map.from_struct() |> Map.drop([:__meta__, :id, :inserted_at, :updated_at] ++ attrs)
  end
end
