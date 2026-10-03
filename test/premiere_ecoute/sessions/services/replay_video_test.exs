defmodule PremiereEcoute.Sessions.Services.ReplayVideoTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Profile
  alias PremiereEcoute.Accounts.User.Profile.VideoSettings
  alias PremiereEcoute.Apis.Video.YoutubeApi.Mock, as: YoutubeApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Services.ReplayVideo
  alias PremiereEcoute.Youtube.Video

  @channel_id "UC" <> String.duplicate("a", 22)
  @channel_uuid "8b1c1a3e-6f0e-4a55-9c2b-0a4d6a3f1e11"
  @ended_at ~U[2026-10-03 21:00:00Z]

  defp session(attrs \\ %{}) do
    channel = %VideoSettings.Channel{id: @channel_uuid, label: "Main", youtube_channel_id: @channel_id}

    struct(
      %ListeningSession{
        source: :album,
        ended_at: @ended_at,
        user: %User{profile: %Profile{video_settings: %VideoSettings{channels: [channel]}}},
        album: %Album{name: "Kid A", artist: %Artist{name: "Radiohead"}}
      },
      attrs
    )
  end

  defp replay(attrs \\ %{}), do: struct(%VideoSettings.Replay{name: "raw", channel_id: @channel_uuid}, attrs)

  defp video(attrs \\ %{}) do
    struct(
      %Video{
        id: "vid#{System.unique_integer([:positive])}",
        title: "PREMIÈRE ÉCOUTE : \"Kid A\" by Radiohead",
        channel_id: @channel_id,
        published_at: "2026-10-04T10:00:00Z",
        privacy: :public
      },
      attrs
    )
  end

  defp find(videos, session \\ session(), replay \\ replay()) do
    expect(YoutubeApi, :get_channel_videos, fn @channel_id, opts ->
      assert opts[:since] == @ended_at
      {:ok, videos}
    end)

    ReplayVideo.find_replay_video(session, replay)
  end

  describe "find_replay_video/2" do
    test "returns the video whose title names the artist and the album" do
      match = video()

      assert {:ok, ^match} = find([video(%{title: "Something else entirely"}), match])
    end

    test "ignores case, accents and punctuation" do
      session = session(%{album: %Album{name: "Café Tacvba", artist: %Artist{name: "Beyoncé"}}})
      match = video(%{title: "BEYONCE - cafe tacvba (réaction!)"})

      assert {:ok, ^match} = find([match], session)
    end

    test "requires both the artist and the album" do
      assert {:error, :not_found} = find([video(%{title: "Kid A reaction"}), video(%{title: "Radiohead live in Paris"})])
    end

    test "ignores videos that are not public" do
      assert {:error, :not_found} = find([video(%{privacy: :unlisted}), video(%{privacy: :private})])
    end

    test "returns the first video when several match" do
      first = video()

      assert {:ok, ^first} = find([first, video()])
    end

    test "returns not found without any video" do
      assert {:error, :not_found} = find([])
    end

    test "returns the API error" do
      expect(YoutubeApi, :get_channel_videos, fn _, _ -> {:error, "YouTube API error: 403"} end)

      assert {:error, "YouTube API error: 403"} = ReplayVideo.find_replay_video(session(), replay())
    end

    test "returns not found when the replay channel is no longer configured" do
      assert {:error, :not_found} =
               ReplayVideo.find_replay_video(session(), replay(%{channel_id: Ecto.UUID.generate()}))
    end

    test "fails when the session has not ended" do
      assert {:error, :session_not_valid} = ReplayVideo.find_replay_video(session(%{ended_at: nil}), replay())
    end
  end
end
