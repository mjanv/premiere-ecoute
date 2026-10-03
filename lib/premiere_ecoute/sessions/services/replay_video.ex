defmodule PremiereEcoute.Sessions.Services.ReplayVideo do
  @moduledoc """
  Finds the YouTube video that holds the replay of a listening session.

  Lists the videos uploaded to the replay channel since the session ended and picks the one whose title
  names the session's artist and album. Matching is intentionally simple: the title only.
  """

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Profile
  alias PremiereEcoute.Accounts.User.Profile.VideoSettings.Channel
  alias PremiereEcoute.Accounts.User.Profile.VideoSettings.Replay
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Youtube.Video

  @doc """
  Looks for the video of `session` for every replay configured by its user.

  The session must come with its `user`. Returns a `{replay, result}` pair per replay, `result` being what
  `find_replay_video/2` returns.
  """
  @spec find_replay_videos(ListeningSession.t()) :: [{Replay.t(), {:ok, Video.t()} | {:error, term()}}]
  def find_replay_videos(%ListeningSession{user: %User{} = user} = session) do
    user
    |> Profile.get([:video_settings, :replays], [])
    |> Enum.map(&{&1, find_replay_video(session, &1)})
  end

  @doc """
  Stores the videos found by `find_replay_videos/1` in the replays of `session`.

  Each `{replay, {:ok, video}}` writes an entry to `ListeningSession.replays` (`label`, `url`, `replay_id`,
  `video_id`, `youtube_channel_id`, `thumbnail_url`, `uploaded_at`, `source: "auto"`). It replaces the entry
  with the same `replay_id` when there is one, and is appended otherwise. Other entries and failed results
  are left untouched.
  """
  @spec store_replay_videos(ListeningSession.t(), [{Replay.t(), {:ok, Video.t()} | {:error, term()}}]) ::
          {:ok, ListeningSession.t()} | {:error, Ecto.Changeset.t()}
  def store_replay_videos(%ListeningSession{replays: replays} = session, results) do
    uploaded_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    results
    |> Enum.flat_map(&entry(&1, uploaded_at))
    |> Enum.reduce(replays, &put_entry/2)
    |> then(&ListeningSession.update_replays(session, &1))
  end

  defp entry({%Replay{id: id} = replay, {:ok, %Video{} = video}}, uploaded_at) when is_binary(id) do
    [
      %{
        "label" => replay.name,
        "url" => video.url,
        "replay_id" => id,
        "video_id" => video.id,
        "youtube_channel_id" => video.channel_id,
        "thumbnail_url" => video.thumbnail_url,
        "uploaded_at" => uploaded_at,
        "source" => "auto"
      }
    ]
  end

  defp entry(_result, _uploaded_at), do: []

  defp put_entry(entry, replays) do
    case Enum.find_index(replays, &(&1["replay_id"] == entry["replay_id"])) do
      nil -> replays ++ [entry]
      index -> List.replace_at(replays, index, entry)
    end
  end

  @doc """
  Looks for the video of `session` on the channel targeted by `replay`.

  Only album sessions are supported. The session must come with its `user` and its album with the artist (as
  `ListeningSession.preload/1` returns it), since the title is matched on `ListeningSession.artist/1`
  and `ListeningSession.title/1`.

  A video matches when it is public and its title contains both the artist and the album name, ignoring
  case, accents and punctuation. Returns `{:ok, video}` with the first matching video, and an error when
  none does or the channel is unknown (`:not_found`), the session has not ended (`:session_not_valid`), or
  YouTube cannot be reached.
  """
  @spec find_replay_video(ListeningSession.t(), Replay.t()) :: {:ok, Video.t()} | {:error, term()}
  def find_replay_video(%ListeningSession{source: :album, user: %User{} = user, ended_at: ended_at} = session, %Replay{
        channel_id: channel_id
      })
      when not is_nil(ended_at) do
    with {artist, album} <- {ListeningSession.artist(session), ListeningSession.title(session)},
         %Channel{youtube_channel_id: yt} <-
           Enum.find(Profile.get(user, [:video_settings, :channels], []), &(&1.id == channel_id)),
         {:ok, videos} <- Apis.youtube().get_channel_videos(yt, since: session.ended_at),
         %Video{} = video <- Enum.find(videos, &match?(&1, artist, album)) do
      {:ok, video}
    else
      {:error, _} = error -> error
      _ -> {:error, :not_found}
    end
  end

  def find_replay_video(%ListeningSession{}, %Replay{}), do: {:error, :session_not_valid}

  defp match?(%Video{privacy: :public, title: title}, artist, album) do
    title = normalize(title)
    String.contains?(title, normalize(artist)) and String.contains?(title, normalize(album))
  end

  defp match?(%Video{}, _artist, _album), do: false

  defp normalize(nil), do: ""

  defp normalize(text) do
    text
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}]+/u, " ")
    |> String.trim()
  end
end
