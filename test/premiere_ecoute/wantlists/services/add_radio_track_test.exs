defmodule PremiereEcoute.Wantlists.Services.AddTrackTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Wantlists

  setup do
    user = user_fixture(%{role: :viewer})
    {:ok, %{user: user}}
  end

  describe "run/2 — existing discography record" do
    test "adds an existing single to the wantlist", %{user: user} do
      {:ok, single} = Single.create_if_not_exists(single_fixture())
      spotify_id = single.provider_ids[:spotify]

      assert {:ok, item} = Wantlists.add_radio_track(user.id, spotify_id)
      assert item.type == :track
      assert item.single_id == single.id
    end

    test "adds the album when a track from it is already in discography", %{user: user} do
      {:ok, album} = Album.create(album_fixture())
      track = hd(album.tracks)
      spotify_id = track.provider_ids[:spotify]

      assert {:ok, item} = Wantlists.add_radio_track(user.id, spotify_id)
      assert item.type == :album
      assert item.album_id == album.id
    end

    test "is idempotent when called twice for the same single", %{user: user} do
      {:ok, single} = Single.create_if_not_exists(single_fixture())
      spotify_id = single.provider_ids[:spotify]

      {:ok, first} = Wantlists.add_radio_track(user.id, spotify_id)
      {:ok, second} = Wantlists.add_radio_track(user.id, spotify_id)
      assert first.id == second.id
    end
  end

  describe "run/2 — track not in discography, fetched from Spotify" do
    test "creates a single and adds it to the wantlist when spotify track is a single", %{user: user} do
      spotify_id = "new_single_spotify_id"

      expect(SpotifyApi, :get_single, fn ^spotify_id ->
        {:ok,
         %Single{
           provider_ids: %{spotify: spotify_id},
           name: "New Single",
           artists: [],
           duration_ms: 200_000,
           cover_url: nil
         }}
      end)

      assert {:ok, item} = Wantlists.add_radio_track(user.id, spotify_id)
      assert item.type == :track
      assert Single.get(item.single_id) != nil
    end

    test "creates an album and adds it to the wantlist when spotify track belongs to an album", %{user: user} do
      track_spotify_id = "new_album_track_id"
      album_spotify_id = "new_album_id"

      expect(SpotifyApi, :get_single, fn ^track_spotify_id -> {:error, :no_track_found} end)

      stub(SpotifyApi, :get_track, fn ^track_spotify_id ->
        {:ok,
         %Album.Track{
           provider_ids: %{spotify: track_spotify_id},
           name: "Track From Album",
           track_number: 1,
           duration_ms: 210_000
         }
         |> Map.put(:album_spotify_id, album_spotify_id)}
      end)

      expect(SpotifyApi, :get_album, fn ^album_spotify_id ->
        {:ok,
         %Album{
           provider_ids: %{spotify: album_spotify_id},
           name: "New Album",
           artists: [],
           release_date: ~D[2024-01-01],
           cover_url: nil,
           total_tracks: 1,
           tracks: [
             %Album.Track{
               provider_ids: %{spotify: track_spotify_id},
               name: "Track From Album",
               track_number: 1,
               duration_ms: 210_000
             }
           ]
         }}
      end)

      assert {:ok, item} = Wantlists.add_radio_track(user.id, track_spotify_id)
      assert item.type == :album
      assert Album.get(item.album_id) != nil
    end

    test "returns error when spotify API fails", %{user: user} do
      spotify_id = "bad_id"
      expect(SpotifyApi, :get_single, fn ^spotify_id -> {:error, :api_error} end)

      assert {:error, :api_error} = Wantlists.add_radio_track(user.id, spotify_id)
    end
  end
end
