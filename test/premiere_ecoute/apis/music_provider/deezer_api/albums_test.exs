defmodule PremiereEcoute.Apis.MusicProvider.DeezerApi.AlbumsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track

  setup {Req.Test, :verify_on_exit!}

  describe "get_album/1" do
    test "get a album from an unique identifier" do
      ApiMock.expect(
        DeezerApi,
        path: {:get, "/album/302127"},
        headers: [{"content-type", "application/json"}],
        response: "deezer_api/albums/get_album/response.json",
        status: 200
      )

      id = "302127"

      {:ok, album} = DeezerApi.get_album(id)

      assert %Album{
               id: nil,
               provider: :deezer,
               album_id: "302127",
               name: "Discovery",
               artist: "Daft Punk",
               release_date: ~D[2001-03-07],
               cover_url: "https://api.deezer.com/album/302127/image",
               total_tracks: 14,
               tracks: [
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135553",
                   album_id: "302127",
                   name: "One More Time",
                   track_number: 1,
                   duration_ms: 320_000
                 },
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135554",
                   album_id: "302127",
                   name: "Aerodynamic",
                   track_number: 2,
                   duration_ms: 212_000
                 },
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135555",
                   album_id: "302127",
                   name: "Digital Love",
                   track_number: 3,
                   duration_ms: 301_000
                 },
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135556",
                   album_id: "302127",
                   name: "Harder, Better, Faster, Stronger",
                   track_number: 4,
                   duration_ms: 226_000
                 },
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135557",
                   album_id: "302127",
                   name: "Crescendolls",
                   track_number: 5,
                   duration_ms: 211_000
                 },
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135558",
                   album_id: "302127",
                   name: "Nightvision",
                   track_number: 6,
                   duration_ms: 104_000
                 },
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135559",
                   album_id: "302127",
                   name: "Superheroes",
                   track_number: 7,
                   duration_ms: 237_000
                 },
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135560",
                   album_id: "302127",
                   name: "High Life",
                   track_number: 8,
                   duration_ms: 201_000
                 },
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135561",
                   album_id: "302127",
                   name: "Something About Us",
                   track_number: 9,
                   duration_ms: 232_000
                 },
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135562",
                   album_id: "302127",
                   name: "Voyager",
                   track_number: 10,
                   duration_ms: 227_000
                 },
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135563",
                   album_id: "302127",
                   name: "Veridis Quo",
                   track_number: 11,
                   duration_ms: 345_000
                 },
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135564",
                   album_id: "302127",
                   name: "Short Circuit",
                   track_number: 12,
                   duration_ms: 206_000
                 },
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135565",
                   album_id: "302127",
                   name: "Face to Face",
                   track_number: 13,
                   duration_ms: 240_000
                 },
                 %Track{
                   id: nil,
                   provider: :deezer,
                   track_id: "3135566",
                   album_id: "302127",
                   name: "Too Long",
                   track_number: 14,
                   duration_ms: 600_000
                 }
               ]
             } = album
    end
  end
end
