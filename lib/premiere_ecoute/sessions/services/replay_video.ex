defmodule PremiereEcoute.Sessions.Services.ReplayVideo do
  @moduledoc """
  Finds the YouTube video that holds the replay of a listening session.

  Lists the videos uploaded to the replay channel since the session ended and picks the one whose title
  names the session's artist and album. Matching is intentionally simple: the title only.
  """

  import Ecto.Query, only: [from: 2]

  require Logger

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Profile
  alias PremiereEcoute.Accounts.User.Profile.VideoSettings.Channel
  alias PremiereEcoute.Accounts.User.Profile.VideoSettings.Replay
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Workers.CheckUploadWorker
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
  Stores the result of `find_replay_video/2` for `replay` in the replays of `session`.

  Same as `store_replay_videos/2` for a single replay: a found video replaces the entry with the same
  `replay_id`, or is appended, and an error leaves the session untouched.
  """
  @spec store_replay_video(ListeningSession.t(), Replay.t(), {:ok, Video.t()} | {:error, term()}) ::
          {:ok, ListeningSession.t()} | {:error, Ecto.Changeset.t()}
  def store_replay_video(%ListeningSession{} = session, %Replay{} = replay, result) do
    store_replay_videos(session, [{replay, result}])
  end

  @doc """
  Stores the videos found by `find_replay_videos/1` in the replays of `session`.

  Each `{replay, {:ok, video}}` writes an entry to `ListeningSession.replays` (`label`, `url`, `replay_id`,
  `video_id`, `youtube_channel_id`, `channel_title`, `thumbnail_url`, `uploaded_at`, `source: "auto"`). It replaces the entry
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

  defp entry({%Replay{id: id, name: name}, {:ok, %Video{} = video}}, uploaded_at) when is_binary(id) do
    [build_entry(video, name, id, "auto", uploaded_at)]
  end

  defp entry(_result, _uploaded_at), do: []

  defp build_entry(%Video{} = video, label, replay_id, source, uploaded_at) do
    %{
      "label" => label,
      "url" => video.url,
      "replay_id" => replay_id,
      "video_id" => video.id,
      "youtube_channel_id" => video.channel_id,
      "channel_title" => video.channel_title,
      "thumbnail_url" => video.thumbnail_url,
      "uploaded_at" => uploaded_at,
      "source" => source
    }
    |> Map.reject(fn {key, value} -> key == "replay_id" and is_nil(value) end)
  end

  @doc """
  Builds the replay entry of a link typed by hand (`%{"label" => ..., "url" => ..., "replay_id" => ...}`).

  `existing` is the entry the form row was opened with, if any. When the link did not change and the entry
  already has its video details (`video_id`), it keeps everything (thumbnail, channel...) and only takes the
  new label and replay. Otherwise, a YouTube link is looked up with `YoutubeApi.get_video/1` and gives the
  same entry the automatic check stores, with `source: "manual"`, so saving a plain entry again completes it. Any other link, or a failed lookup, gives a plain `label` and `url` entry.
  A blank `replay_id` unlinks the entry from its replay, and no `replay_id` key at all leaves it as it was.
  """
  @spec manual_entry(map(), map() | nil) :: map()
  def manual_entry(%{"url" => url} = submitted, existing) do
    replay_id = if submitted["replay_id"] not in [nil, ""], do: submitted["replay_id"]
    now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    case existing do
      %{"url" => ^url, "video_id" => _} ->
        merged = Map.merge(existing, Map.take(submitted, ["label"]))

        if Map.has_key?(submitted, "replay_id"),
          do: merged |> Map.delete("replay_id") |> put_replay_id(replay_id),
          else: merged

      _ ->
        with {:ok, id} <- Video.id_from_url(url),
             {:ok, %Video{} = video} <- Apis.youtube().get_video(id) do
          build_entry(%{video | url: url}, submitted["label"], replay_id, "manual", now)
        else
          :error ->
            %{"label" => submitted["label"], "url" => url} |> put_replay_id(replay_id)

          {:error, reason} ->
            Logger.warning("Replay link lookup failed for #{url}: #{inspect(reason)}")
            %{"label" => submitted["label"], "url" => url} |> put_replay_id(replay_id)
        end
    end
  end

  defp put_replay_id(entry, nil), do: entry
  defp put_replay_id(entry, replay_id), do: Map.put(entry, "replay_id", replay_id)

  defp put_entry(entry, replays) do
    case Enum.find_index(replays, &(&1["replay_id"] == entry["replay_id"])) do
      nil -> replays ++ [entry]
      index -> List.replace_at(replays, index, entry)
    end
  end

  @doc """
  Schedules one `CheckUploadWorker` job per replay of the user of the session `session_id`.

  Only ended album sessions are scheduled, when the user enabled
  upload reminders and the session ended since `tracking_since`. Each job runs at `ended_at` plus the
  replay's delay, and a `pending` entry is written in `options["uploads"]` under the replay id. Replays that
  already have an entry are left alone, so calling it twice is harmless.
  """
  @spec schedule_upload_checks(integer()) :: :ok
  def schedule_upload_checks(session_id) do
    with %ListeningSession{source: :album, user: %User{} = user, ended_at: %DateTime{} = ended_at} <-
           session_id |> ListeningSession.get() |> ListeningSession.preload(),
         true <- Profile.get(user, [:video_settings, :reminders_enabled], false),
         %Date{} = since <- Profile.get(user, [:video_settings, :tracking_since]),
         false <- Date.before?(DateTime.to_date(ended_at), since),
         [_ | _] = replays <- Profile.get(user, [:video_settings, :replays], []) do
      config = Application.fetch_env!(:premiere_ecoute, __MODULE__)

      {:ok, _} =
        Repo.transaction(fn ->
          session = Repo.one!(from(s in ListeningSession, where: s.id == ^session_id, lock: "FOR UPDATE"))
          uploads = session.options["uploads"] || %{}

          new =
            for replay <- replays, not is_map_key(uploads, replay.id), into: %{} do
              due_at = DateTime.add(ended_at, replay.delay_hours, :hour)
              {:ok, job} = CheckUploadWorker.start(%{session_id: session.id, replay_id: replay.id}, scheduled_at: due_at)

              {replay.id,
               %{
                 "status" => "pending",
                 "job_id" => job.id,
                 "due_at" => DateTime.to_iso8601(due_at),
                 "iterations" => 0,
                 "max_iterations" => config[:max_iterations],
                 "interval_hours" => config[:interval_hours],
                 "last_checked_at" => nil,
                 "next_check_at" => DateTime.to_iso8601(due_at),
                 "last_failure" => nil
               }}
            end

          session
          |> ListeningSession.changeset(%{options: Map.put(session.options, "uploads", Map.merge(uploads, new))})
          |> Repo.update!()
        end)

      :ok
    else
      _ -> :ok
    end
  end

  @doc """
  Looks once for the replays of the session `session_id` that have no entry yet.

  A replay is missing when none of the session's `replays` entries carries its id. Each missing replay of the
  user is looked up with `find_replay_video/2`, outside any transaction. The videos found are then stored
  under a lock on the session, unless an entry for the replay appeared meanwhile, and a replay still
  `pending` in `options["uploads"]` becomes `found` and has its job cancelled. Replays that are not found
  are left alone: no iteration is counted and no job is scheduled.

  Returns the replays `found`, the ones still `missing`, and the ones whose lookup `failed` (YouTube could
  not be reached). Only ended album sessions are supported.
  """
  @spec sync_replay_videos(integer()) ::
          {:ok, %{found: [Replay.t()], missing: [Replay.t()], failed: [Replay.t()]}} | {:error, term()}
  def sync_replay_videos(session_id) do
    case session_id |> ListeningSession.get() |> ListeningSession.preload() do
      %ListeningSession{source: :album, user: %User{} = user, ended_at: %DateTime{}} = session ->
        linked = MapSet.new(session.replays, & &1["replay_id"])

        results =
          user
          |> Profile.get([:video_settings, :replays], [])
          |> Enum.reject(&MapSet.member?(linked, &1.id))
          |> Enum.map(&{&1, find_replay_video(session, &1)})

        {:ok, found} =
          Repo.transaction(fn ->
            locked = Repo.one!(from(s in ListeningSession, where: s.id == ^session_id, lock: "FOR UPDATE"))
            linked = MapSet.new(locked.replays, & &1["replay_id"])

            found =
              Enum.filter(results, fn {replay, result} -> match?({:ok, _}, result) and not MapSet.member?(linked, replay.id) end)

            now = DateTime.utc_now(:second)

            {:ok, stored} = store_replay_videos(locked, found)

            uploads =
              Enum.reduce(found, locked.options["uploads"] || %{}, fn {replay, _}, acc ->
                Map.replace_lazy(acc, replay.id, &finish_upload(&1, now))
              end)

            options = if locked.options["uploads"], do: Map.put(locked.options, "uploads", uploads), else: locked.options

            stored |> ListeningSession.changeset(%{options: options}) |> Repo.update!()
            Enum.map(found, &elem(&1, 0))
          end)

        rest = Enum.reject(results, fn {replay, _} -> replay in found end)

        {:ok,
         %{
           found: found,
           missing: for({replay, {:error, :not_found}} <- rest, do: replay),
           failed: for({replay, {:error, reason}} <- rest, reason != :not_found, do: replay)
         }}

      nil ->
        {:error, :not_found}

      %ListeningSession{} ->
        {:error, :session_not_valid}
    end
  end

  defp finish_upload(%{"status" => "pending", "job_id" => job_id} = state, now) do
    if job_id, do: Oban.cancel_job(job_id)
    CheckUploadWorker.mark_found(state, now)
  end

  defp finish_upload(state, _now), do: state

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
