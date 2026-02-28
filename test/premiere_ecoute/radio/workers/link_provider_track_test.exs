defmodule PremiereEcoute.Radio.Workers.LinkProviderTrackTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Radio
  alias PremiereEcoute.Radio.Workers.LinkProviderTrack

  setup {Req.Test, :verify_on_exit!}

  # Insert the track in manual mode so the scheduled worker job is not executed immediately.
  defp radio_track_fixture(provider, provider_ids) do
    user = user_fixture()

    Oban.Testing.with_testing_mode(:manual, fn ->
      {:ok, track} =
        Radio.insert_track(user.id, provider, %{
          provider_ids: provider_ids,
          name: "Around the World",
          artist: "Daft Punk",
          album: "Homework",
          duration_ms: 429_533,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      track
    end)
  end

  describe "perform/1" do
    test "resolves deezer_id when only spotify_id is known" do
      track = radio_track_fixture("spotify", %{spotify: "1pKYYY0dkg23sQQXi0Q5zN"})

      ApiMock.expect(DeezerApi,
        path: {:get, "/search"},
        params: %{"q" => "Daft Punk Around the World"},
        status: 200,
        body: %{
          "data" => [
            %{
              "id" => 3_135_556,
              "title" => "Around the World",
              "track_position" => 7,
              "duration" => 429
            }
          ]
        }
      )

      :ok = perform_job(LinkProviderTrack, %{radio_track_id: track.id, provider: "spotify"})

      track = Radio.get_track(track.id)
      assert track.provider_ids == %{spotify: "1pKYYY0dkg23sQQXi0Q5zN", deezer: "3135556"}
    end

    test "resolves spotify_id when only deezer_id is known" do
      track = radio_track_fixture("deezer", %{deezer: "3135556"})

      Mox.expect(SpotifyApi, :search_tracks, fn [query: "Daft Punk Around the World"] ->
        {:ok,
         [
           %{
             track_id: "1pKYYY0dkg23sQQXi0Q5zN",
             name: "Around the World"
           }
         ]}
      end)

      :ok = perform_job(LinkProviderTrack, %{radio_track_id: track.id, provider: "deezer"})

      track = Radio.get_track(track.id)
      assert track.provider_ids == %{deezer: "3135556", spotify: "1pKYYY0dkg23sQQXi0Q5zN"}
    end

    test "does nothing when all known provider ids are already present" do
      track = radio_track_fixture("spotify", %{spotify: "1pKYYY0dkg23sQQXi0Q5zN", deezer: "3135556"})

      :ok = perform_job(LinkProviderTrack, %{radio_track_id: track.id, provider: "spotify"})

      track = Radio.get_track(track.id)
      assert track.provider_ids == %{spotify: "1pKYYY0dkg23sQQXi0Q5zN", deezer: "3135556"}
    end

    test "does nothing when search returns empty results" do
      track = radio_track_fixture("spotify", %{spotify: "1pKYYY0dkg23sQQXi0Q5zN"})

      ApiMock.expect(DeezerApi,
        path: {:get, "/search"},
        params: %{"q" => "Daft Punk Around the World"},
        status: 200,
        body: %{"data" => []}
      )

      :ok = perform_job(LinkProviderTrack, %{radio_track_id: track.id, provider: "spotify"})

      track = Radio.get_track(track.id)
      assert track.provider_ids == %{spotify: "1pKYYY0dkg23sQQXi0Q5zN"}
    end
  end

  describe "scheduling" do
    test "is scheduled 15 seconds after a track is inserted" do
      user = user_fixture()

      Oban.Testing.with_testing_mode(:manual, fn ->
        Radio.insert_track(user.id, "spotify", %{
          provider_ids: %{spotify: "1pKYYY0dkg23sQQXi0Q5zN"},
          name: "Around the World",
          artist: "Daft Punk",
          duration_ms: 429_533,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

        assert_enqueued worker: LinkProviderTrack,
                        scheduled_at: {DateTime.utc_now() |> DateTime.add(15, :second), delta: 5}
      end)
    end

    test "is not scheduled when insert is a consecutive duplicate" do
      user = user_fixture()
      started_at = DateTime.utc_now() |> DateTime.truncate(:second)

      track_data = %{
        provider_ids: %{spotify: "1pKYYY0dkg23sQQXi0Q5zN"},
        name: "Around the World",
        artist: "Daft Punk",
        duration_ms: 429_533,
        started_at: started_at
      }

      Oban.Testing.with_testing_mode(:manual, fn ->
        Radio.insert_track(user.id, "spotify", track_data)
        {:error, :consecutive_duplicate} = Radio.insert_track(user.id, "spotify", track_data)

        assert [_] = all_enqueued(worker: LinkProviderTrack)
      end)
    end
  end
end
