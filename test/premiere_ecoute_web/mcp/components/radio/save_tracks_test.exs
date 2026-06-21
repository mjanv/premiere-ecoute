defmodule PremiereEcouteWeb.Mcp.Components.Radio.SaveTracksTest do
  use PremiereEcoute.DataCase, async: false

  import PremiereEcoute.AccountsFixtures

  alias Hermes.Server.Frame
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Radio.RadioTrack
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Wantlists
  alias PremiereEcouteWeb.Mcp.Components.Radio.SaveTracks

  setup_mock(Wantlists)

  defp frame(user), do: Frame.assign(%Frame{}, :current_user, user)

  defp public_streamer do
    user = user_fixture()
    {:ok, user} = User.edit_user_profile(user, %{radio_settings: %{visibility: :public, enabled: true}})
    user
  end

  defp insert_radio_track(user, attrs) do
    defaults = %{
      user_id: user.id,
      name: "Track #{System.unique_integer([:positive])}",
      artist: "Some Artist",
      album: "Album",
      duration_ms: 180_000,
      started_at: DateTime.utc_now() |> DateTime.truncate(:second),
      provider_ids: %{spotify: "sp-#{System.unique_integer([:positive])}"}
    }

    Repo.insert!(%RadioTrack{} |> RadioTrack.changeset(Map.merge(defaults, attrs)))
  end

  describe "execute/2" do
    test "saves a track by spotify_id" do
      streamer = public_streamer()
      track = insert_radio_track(streamer, %{provider_ids: %{spotify: "sp-abc"}})
      viewer = user_fixture()

      expect(Wantlists.Mock, :add_radio_track, fn user_id, spotify_id ->
        assert user_id == viewer.id
        assert spotify_id == "sp-abc"
        {:ok, %Wantlists.WantlistItem{id: 1}}
      end)

      assert {:reply, resp, _} =
               SaveTracks.execute(
                 %{username: streamer.username, spotify_id: track.provider_ids[:spotify]},
                 frame(viewer)
               )

      refute resp.isError
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "Saved 1"
    end

    test "saves all tracks by artist name" do
      streamer = public_streamer()
      insert_radio_track(streamer, %{artist: "Daft Punk", name: "Get Lucky"})
      insert_radio_track(streamer, %{artist: "Daft Punk", name: "Harder Better"})
      insert_radio_track(streamer, %{artist: "Other Artist", name: "Unrelated"})
      viewer = user_fixture()

      expect(Wantlists.Mock, :add_radio_track, 2, fn _user_id, _spotify_id ->
        {:ok, %Wantlists.WantlistItem{id: 1}}
      end)

      assert {:reply, resp, _} =
               SaveTracks.execute(%{username: streamer.username, artist_name: "Daft Punk"}, frame(viewer))

      assert [%{"text" => msg}] = resp.content
      assert msg =~ "Saved 2"
    end

    test "saves tracks filtered by track name" do
      streamer = public_streamer()
      insert_radio_track(streamer, %{name: "Get Lucky", artist: "Daft Punk"})
      insert_radio_track(streamer, %{name: "Harder Better", artist: "Daft Punk"})
      viewer = user_fixture()

      expect(Wantlists.Mock, :add_radio_track, 1, fn _user_id, _spotify_id ->
        {:ok, %Wantlists.WantlistItem{id: 1}}
      end)

      assert {:reply, resp, _} =
               SaveTracks.execute(%{username: streamer.username, track_name: "Get Lucky"}, frame(viewer))

      assert [%{"text" => msg}] = resp.content
      assert msg =~ "Saved 1"
    end

    test "filter is case-insensitive" do
      streamer = public_streamer()
      insert_radio_track(streamer, %{artist: "Daft Punk", name: "Get Lucky"})
      viewer = user_fixture()

      expect(Wantlists.Mock, :add_radio_track, 1, fn _user_id, _spotify_id ->
        {:ok, %Wantlists.WantlistItem{id: 1}}
      end)

      assert {:reply, resp, _} =
               SaveTracks.execute(%{username: streamer.username, artist_name: "daft punk"}, frame(viewer))

      assert [%{"text" => msg}] = resp.content
      assert msg =~ "Saved 1"
    end

    test "combining track_name and artist_name filters both" do
      streamer = public_streamer()
      insert_radio_track(streamer, %{name: "Get Lucky", artist: "Daft Punk"})
      insert_radio_track(streamer, %{name: "Get Lucky", artist: "Other Artist"})
      viewer = user_fixture()

      expect(Wantlists.Mock, :add_radio_track, 1, fn _user_id, _spotify_id ->
        {:ok, %Wantlists.WantlistItem{id: 1}}
      end)

      assert {:reply, resp, _} =
               SaveTracks.execute(
                 %{username: streamer.username, track_name: "Get Lucky", artist_name: "Daft Punk"},
                 frame(viewer)
               )

      assert [%{"text" => msg}] = resp.content
      assert msg =~ "Saved 1"
    end

    test "reports partial failures" do
      streamer = public_streamer()
      insert_radio_track(streamer, %{name: "Track A", artist: "Artist"})
      insert_radio_track(streamer, %{name: "Track B", artist: "Artist"})
      viewer = user_fixture()

      expect(Wantlists.Mock, :add_radio_track, fn _user_id, _spotify_id ->
        {:ok, %Wantlists.WantlistItem{id: 1}}
      end)

      expect(Wantlists.Mock, :add_radio_track, fn _user_id, _spotify_id ->
        {:error, :not_found}
      end)

      assert {:reply, resp, _} =
               SaveTracks.execute(%{username: streamer.username, artist_name: "Artist"}, frame(viewer))

      assert [%{"text" => msg}] = resp.content
      assert msg =~ "1 failed"
    end

    test "returns error when no tracks match the filter" do
      streamer = public_streamer()
      insert_radio_track(streamer, %{artist: "Daft Punk"})
      viewer = user_fixture()

      assert {:reply, resp, _} =
               SaveTracks.execute(%{username: streamer.username, artist_name: "Nobody"}, frame(viewer))

      assert resp.isError == true
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "No matching tracks"
    end

    test "returns error for unknown username" do
      viewer = user_fixture()

      assert {:reply, resp, _} =
               SaveTracks.execute(%{username: "nobody-#{System.unique_integer()}"}, frame(viewer))

      assert resp.isError == true
    end

    test "returns error for private radio" do
      streamer = user_fixture()
      {:ok, streamer} = User.edit_user_profile(streamer, %{radio_settings: %{visibility: :private}})
      viewer = user_fixture()

      assert {:reply, resp, _} = SaveTracks.execute(%{username: streamer.username}, frame(viewer))
      assert resp.isError == true
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "private"
    end

    test "returns error for invalid date" do
      streamer = public_streamer()
      viewer = user_fixture()

      assert {:reply, resp, _} =
               SaveTracks.execute(%{username: streamer.username, date: "bad-date"}, frame(viewer))

      assert resp.isError == true
    end
  end
end
