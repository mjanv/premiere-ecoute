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

  describe "manual_entry/2" do
    @url "https://youtu.be/dQw4w9WgXcQ?t=3"

    test "gives a typed YouTube link the same entry as the automatic check" do
      found = video(%{id: "dQw4w9WgXcQ", channel_title: "Lanfeust Plays", thumbnail_url: "https://i.ytimg.com/vi/x/hq.jpg"})
      expect(YoutubeApi, :get_video, fn "dQw4w9WgXcQ" -> {:ok, found} end)

      entry = ReplayVideo.manual_entry(%{"label" => "raw", "url" => @url, "replay_id" => "r1"}, nil)

      assert %{
               "label" => "raw",
               "url" => @url,
               "replay_id" => "r1",
               "video_id" => "dQw4w9WgXcQ",
               "youtube_channel_id" => @channel_id,
               "channel_title" => "Lanfeust Plays",
               "thumbnail_url" => "https://i.ytimg.com/vi/x/hq.jpg",
               "source" => "manual"
             } = entry

      assert {:ok, _, _} = DateTime.from_iso8601(entry["uploaded_at"])
    end

    test "has no replay without one chosen" do
      expect(YoutubeApi, :get_video, fn _ -> {:ok, video(%{id: "dQw4w9WgXcQ"})} end)

      entry = ReplayVideo.manual_entry(%{"label" => "raw", "url" => @url, "replay_id" => ""}, nil)

      refute Map.has_key?(entry, "replay_id")
    end

    test "keeps a plain entry for a link that is not YouTube, without any lookup" do
      assert ReplayVideo.manual_entry(%{"label" => "VOD", "url" => "https://www.twitch.tv/videos/1"}, nil) ==
               %{"label" => "VOD", "url" => "https://www.twitch.tv/videos/1"}
    end

    test "keeps a plain entry when the lookup fails" do
      expect(YoutubeApi, :get_video, fn _ -> {:error, "YouTube API error: 404"} end)

      assert ReplayVideo.manual_entry(%{"label" => "raw", "url" => @url, "replay_id" => "r1"}, nil) ==
               %{"label" => "raw", "url" => @url, "replay_id" => "r1"}
    end

    test "completes a plain entry with the same link when it is saved again" do
      expect(YoutubeApi, :get_video, fn "dQw4w9WgXcQ" -> {:ok, video(%{id: "dQw4w9WgXcQ"})} end)
      plain = %{"label" => "raw", "url" => @url}

      assert %{"video_id" => "dQw4w9WgXcQ", "source" => "manual", "url" => @url} =
               ReplayVideo.manual_entry(%{"label" => "raw", "url" => @url}, plain)
    end

    test "adds the title to an entry linked before titles were stored" do
      expect(YoutubeApi, :get_video, fn "dQw4w9WgXcQ" -> {:ok, video(%{id: "dQw4w9WgXcQ", title: "Kid A"})} end)
      untitled = %{"label" => "raw", "url" => @url, "video_id" => "dQw4w9WgXcQ", "replay_id" => "r1", "source" => "auto"}

      assert %{"title" => "Kid A", "video_id" => "dQw4w9WgXcQ", "replay_id" => "r1"} =
               ReplayVideo.manual_entry(%{"label" => "raw", "url" => @url, "replay_id" => "r1"}, untitled)
    end

    test "keeps the details of an entry whose link did not change" do
      existing = %{
        "label" => "raw",
        "url" => @url,
        "video_id" => "dQw4w9WgXcQ",
        "title" => "Kid A",
        "replay_id" => "r1",
        "source" => "auto"
      }

      assert ReplayVideo.manual_entry(%{"label" => "cut", "url" => @url, "replay_id" => "r2"}, existing) ==
               %{existing | "label" => "cut", "replay_id" => "r2"}

      assert ReplayVideo.manual_entry(%{"label" => "cut", "url" => @url, "replay_id" => ""}, existing) ==
               existing |> Map.put("label", "cut") |> Map.delete("replay_id")

      assert ReplayVideo.manual_entry(%{"label" => "cut", "url" => @url}, existing) == %{existing | "label" => "cut"}
    end
  end

  describe "store_replay_videos/2" do
    setup do
      user = user_fixture(%{role: :streamer})
      {:ok, album} = Album.create(album_fixture())
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, session: session}
    end

    test "stores the found videos in the session replays", %{session: session} do
      replay = replay(%{id: Ecto.UUID.generate()})

      found =
        video(%{
          url: "https://www.youtube.com/watch?v=abc",
          thumbnail_url: "https://i.ytimg.com/vi/abc/hq.jpg",
          channel_title: "Lanfeust Plays"
        })

      assert {:ok, stored} = ReplayVideo.store_replay_videos(session, [{replay, {:ok, found}}])

      assert [entry] = ListeningSession.get(stored.id).replays
      assert entry["label"] == "raw"
      assert entry["url"] == found.url
      assert entry["replay_id"] == replay.id
      assert entry["video_id"] == found.id
      assert entry["youtube_channel_id"] == @channel_id
      assert entry["channel_title"] == "Lanfeust Plays"
      assert entry["title"] == "PREMIÈRE ÉCOUTE : \"Kid A\" by Radiohead"
      assert entry["thumbnail_url"] == "https://i.ytimg.com/vi/abc/hq.jpg"
      assert entry["source"] == "auto"
      assert {:ok, _, _} = DateTime.from_iso8601(entry["uploaded_at"])
    end

    test "stores the result of a single replay", %{session: session} do
      replay = replay(%{id: Ecto.UUID.generate()})
      found = video(%{url: "https://www.youtube.com/watch?v=abc"})

      assert {:ok, ^session} = ReplayVideo.store_replay_video(session, replay, {:error, :not_found})
      assert {:ok, stored} = ReplayVideo.store_replay_video(session, replay, {:ok, found})
      assert [%{"replay_id" => replay_id, "video_id" => video_id}] = stored.replays
      assert replay_id == replay.id
      assert video_id == found.id
    end

    test "keeps the existing replays and ignores failed results", %{session: session} do
      {:ok, session} =
        ListeningSession.update_replays(session, [%{"label" => "Twitch VOD", "url" => "https://twitch.tv/videos/1"}])

      found = video(%{url: "https://www.youtube.com/watch?v=abc"})

      results = [{replay(%{id: Ecto.UUID.generate()}), {:ok, found}}, {replay(%{name: "edited"}), {:error, :not_found}}]

      assert {:ok, stored} = ReplayVideo.store_replay_videos(session, results)
      assert [%{"label" => "Twitch VOD"}, %{"video_id" => video_id}] = stored.replays
      assert video_id == found.id
    end

    test "rewrites the entry of the same replay and leaves the others untouched", %{session: session} do
      raw = replay(%{id: Ecto.UUID.generate()})
      other = replay(%{id: Ecto.UUID.generate(), name: "edited"})
      manual = %{"label" => "Twitch VOD", "url" => "https://twitch.tv/videos/1"}
      old = %{"label" => "edited", "url" => "https://youtu.be/old", "replay_id" => other.id, "source" => "manual"}
      {:ok, session} = ListeningSession.update_replays(session, [old, manual])

      first = video(%{url: "https://www.youtube.com/watch?v=one"})
      second = video(%{url: "https://www.youtube.com/watch?v=two"})

      {:ok, once} = ReplayVideo.store_replay_videos(session, [{raw, {:ok, first}}])
      {:ok, twice} = ReplayVideo.store_replay_videos(once, [{raw, {:ok, second}}])

      assert [^old, ^manual, %{"replay_id" => replay_id, "video_id" => video_id}] = twice.replays
      assert replay_id == raw.id
      assert video_id == second.id
    end
  end

  describe "find_replay_videos/1" do
    test "looks for the video of every replay of the user" do
      raw = replay()
      other = replay(%{name: "reaction", channel_id: "5d1f8f0a-0b52-4c43-8a3e-2f1c7b9e4d22"})
      session = update_in(session().user.profile.video_settings, &%{&1 | replays: [raw, other]})
      match = video()

      expect(YoutubeApi, :get_channel_videos, fn @channel_id, _ -> {:ok, [match]} end)

      assert [{^raw, {:ok, ^match}}, {^other, {:error, :not_found}}] =
               ReplayVideo.find_replay_videos(session)
    end

    test "returns nothing when the user has no replay" do
      assert [] = ReplayVideo.find_replay_videos(session())
    end
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
