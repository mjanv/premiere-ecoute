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
  alias PremiereEcoute.Sessions.Workers.CheckUploadNowWorker
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

  Each `{replay, {:ok, video}}` writes the video to the entry of `ListeningSession.replays` that has the
  `replay_id` (see `found_entry/5`), or appends one when there is none. Other entries and failed results are
  left untouched.
  """
  @spec store_replay_videos(ListeningSession.t(), [{Replay.t(), {:ok, Video.t()} | {:error, term()}}]) ::
          {:ok, ListeningSession.t()} | {:error, Ecto.Changeset.t()}
  def store_replay_videos(%ListeningSession{replays: replays} = session, results) do
    now = DateTime.utc_now(:second)

    results
    |> Enum.reduce(replays, fn
      {%Replay{id: id} = replay, {:ok, %Video{} = video}}, acc when is_binary(id) ->
        put_entry(found_entry(slot(acc, id) || %{}, replay, video, "auto", now), acc)

      _failed, acc ->
        acc
    end)
    |> then(&ListeningSession.update_replays(session, &1))
  end

  @video_fields ~w(url video_id title youtube_channel_id channel_title thumbnail_url uploaded_at source)

  @doc """
  Returns the status of an entry of `ListeningSession.replays`.

  An entry of a configured replay (it has a `replay_id`) is a slot. Its `status` is `pending` (the worker is
  looking for the video), `found`, `exhausted` (no iteration left), `rejected` (the streamer unmarked a
  wrong auto-match) or `skipped`. A slot without a `status` but with a `url` is `found`: it was linked by hand
  or stored without any tracking. Free links (no `replay_id`) have no status.
  """
  @spec status(map()) :: String.t() | nil
  def status(%{"status" => status}), do: status
  def status(%{"replay_id" => _, "url" => url}) when is_binary(url), do: "found"
  def status(_entry), do: nil

  @doc """
  Returns the slots of `session`: its entries that belong to a configured replay, in order.

  A replay has one slot. If several entries carry the same `replay_id`, the first one is the slot.
  """
  @spec slots(ListeningSession.t()) :: [map()]
  def slots(%ListeningSession{replays: replays}) do
    (replays || [])
    |> Enum.filter(&(is_binary(&1["replay_id"]) and status(&1) != nil))
    |> Enum.uniq_by(& &1["replay_id"])
  end

  @doc "Returns how many slots of `session` are missing: the ones `pending`, `exhausted` or `rejected`."
  @spec missing_count(ListeningSession.t()) :: non_neg_integer()
  def missing_count(%ListeningSession{} = session) do
    Enum.count(slots(session), &(status(&1) in ["pending", "exhausted", "rejected"]))
  end

  @doc "Returns how many slots of `session` need the streamer: the ones `exhausted` or `rejected`."
  @spec attention_count(ListeningSession.t()) :: non_neg_integer()
  def attention_count(%ListeningSession{} = session) do
    Enum.count(slots(session), &(status(&1) in ["exhausted", "rejected"]))
  end

  @doc "Returns the entry of `replays` that belongs to the replay `replay_id`, if any."
  @spec slot([map()], String.t()) :: map() | nil
  def slot(replays, replay_id), do: Enum.find(replays, &(&1["replay_id"] == replay_id))

  @doc """
  Returns `entry` with the video found for `replay`: the video fields (`url`, `video_id`, `channel_title`,
  `thumbnail_url`...) replace the ones it had, and a tracked slot (one with a `status`) becomes `found`, with
  no next check and no job.
  """
  @spec found_entry(map(), Replay.t(), Video.t(), String.t(), DateTime.t()) :: map()
  def found_entry(entry, %Replay{id: id, name: name}, %Video{} = video, source, %DateTime{} = now) do
    entry =
      entry
      |> Map.drop(@video_fields)
      |> Map.merge(build_entry(video, name, id, source, DateTime.to_iso8601(now)))

    if tracked?(entry), do: mark_found(entry, now), else: entry
  end

  defp tracked?(entry), do: is_map_key(entry, "status")

  defp mark_found(entry, now) do
    Map.merge(entry, %{
      "status" => "found",
      "last_checked_at" => DateTime.to_iso8601(now),
      "job_id" => nil
    })
  end

  defp tracking_defaults do
    %{"job_id" => nil, "due_at" => DateTime.to_iso8601(DateTime.utc_now(:second)), "last_checked_at" => nil}
  end

  @doc "Number of checks a replay gets before it is `exhausted`: the `iteration` its first job starts with."
  @spec max_iterations() :: pos_integer()
  def max_iterations, do: Application.fetch_env!(:premiere_ecoute, __MODULE__)[:max_iterations]

  @doc "Hours between two checks of the same replay."
  @spec interval_hours() :: pos_integer()
  def interval_hours, do: Application.fetch_env!(:premiere_ecoute, __MODULE__)[:interval_hours]

  defp lock_session(session_id), do: Repo.one(from(s in ListeningSession, where: s.id == ^session_id, lock: "FOR UPDATE"))

  defp cancel_job(%{"job_id" => job_id}) when is_integer(job_id), do: Oban.cancel_job(job_id)
  defp cancel_job(_entry), do: :ok

  defp build_entry(%Video{} = video, label, replay_id, source, uploaded_at) do
    %{
      "label" => label,
      "url" => video.url,
      "replay_id" => replay_id,
      "video_id" => video.id,
      "title" => video.title,
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
  already has its video details (`video_id` and `title`), it keeps everything (thumbnail, channel...) and only takes the
  new label and replay. Otherwise, a YouTube link is looked up with `YoutubeApi.get_video/1` and gives the
  same entry the automatic check stores, with `source: "manual"`, so saving a plain entry, or one stored before the title existed, again completes it. Any other link, or a failed lookup, gives a plain `label` and `url` entry.
  A blank `replay_id` unlinks the entry from its replay, and no `replay_id` key at all leaves it as it was.
  """
  @spec manual_entry(map(), map() | nil) :: map()
  def manual_entry(%{"url" => url} = submitted, existing) do
    replay_id = if submitted["replay_id"] not in [nil, ""], do: submitted["replay_id"]
    now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    case existing do
      %{"url" => ^url, "video_id" => _, "title" => title} when is_binary(title) ->
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

  @doc false
  def put_entry(entry, replays) do
    case Enum.find_index(replays, &(&1["replay_id"] == entry["replay_id"])) do
      nil -> replays ++ [entry]
      index -> List.replace_at(replays, index, entry)
    end
  end

  @doc """
  Schedules one `CheckUploadWorker` job per replay of the user of the session `session_id`.

  Only ended album sessions are scheduled, when the user enabled upload reminders and the session ended
  since `tracking_since`. Each job runs at `ended_at` plus the replay's delay, and a `pending` entry is added
  to the `replays` of the session, with the `replay_id` and no `url` yet. Replays that already have an entry
  are left alone, so calling it twice is harmless.
  """
  @spec schedule_upload_checks(integer()) :: :ok
  def schedule_upload_checks(session_id) do
    with %ListeningSession{source: :album, user: %User{} = user, ended_at: %DateTime{} = ended_at} <-
           session_id |> ListeningSession.get() |> ListeningSession.preload(),
         true <- Profile.get(user, [:video_settings, :reminders_enabled], false),
         %Date{} = since <- Profile.get(user, [:video_settings, :tracking_since]),
         false <- Date.before?(DateTime.to_date(ended_at), since),
         [_ | _] = replays <- Profile.get(user, [:video_settings, :replays], []) do
      schedule_slots(session_id, ended_at, replays)
      :ok
    else
      _ -> :ok
    end
  end

  @doc """
  Starts the tracking of the replays of one session by hand, as if it had just stopped.

  For a session that existed before the user enabled the reminders: same as `schedule_upload_checks/1`, but it
  ignores `reminders_enabled` and `tracking_since`. Every replay configured by the user that has no entry in
  the session gets a `pending` slot and a job due at `ended_at` plus its delay. That date is already past, so
  the first check runs at once: it settles the replay when the video exists, and otherwise the daily checks go
  on until the replay is `exhausted`. Replays that already have an entry are left alone, so calling it twice is
  harmless.

  Returns the names of the replays `scheduled` and of the ones that already had an `existing` entry. Errors:
  `:not_found`, `:session_not_valid` (not an ended album session) and `:no_replays` (none configured).
  """
  @spec backfill_replay(integer()) :: {:ok, %{scheduled: [String.t()], existing: [String.t()]}} | {:error, term()}
  def backfill_replay(session_id) do
    case session_id |> ListeningSession.get() |> ListeningSession.preload() do
      %ListeningSession{source: :album, user: %User{} = user, ended_at: %DateTime{} = ended_at} ->
        case Profile.get(user, [:video_settings, :replays], []) do
          [_ | _] = replays -> {:ok, schedule_slots(session_id, ended_at, replays)}
          _ -> {:error, :no_replays}
        end

      nil ->
        {:error, :not_found}

      %ListeningSession{} ->
        {:error, :session_not_valid}
    end
  end

  defp schedule_slots(session_id, ended_at, replays) do
    {:ok, result} =
      Repo.transaction(fn ->
        session = session_id |> lock_session() |> Kernel.||(raise "session #{session_id} is gone")
        {existing, missing} = Enum.split_with(replays, &slot(session.replays, &1.id))

        new =
          for replay <- missing do
            due_at = DateTime.to_iso8601(DateTime.add(ended_at, replay.delay_hours, :hour))

            {:ok, job} =
              CheckUploadWorker.start(
                %{session_id: session_id, replay_id: replay.id, iteration: max_iterations()},
                scheduled_at: due_at
              )

            Map.merge(tracking_defaults(), %{
              "replay_id" => replay.id,
              "label" => replay.name,
              "status" => "pending",
              "job_id" => job.id,
              "due_at" => due_at
            })
          end

        session |> ListeningSession.changeset(%{replays: session.replays ++ new}) |> Repo.update!()
        %{scheduled: Enum.map(missing, & &1.name), existing: Enum.map(existing, & &1.name)}
      end)

    result
  end

  @doc """
  Looks once for the replays of the session `session_id` whose video is not known yet.

  A replay is missing when it has no entry in the `replays` of the session, or an entry that is `pending` or
  `exhausted`. `skipped` replays are left out (the streamer chose so), and so are `rejected` ones (the same
  wrong video would match again). Each missing replay is looked up with `find_replay_video/2`, outside any
  transaction. The videos found are then stored under a lock on the session, unless the replay was settled
  meanwhile, and a pending job is cancelled. Replays that are not found are left alone: no iteration is
  counted and no job is scheduled.

  Returns the replays `found`, the ones still `missing`, and the ones whose lookup `failed` (YouTube could
  not be reached). Only ended album sessions are supported.
  """
  @spec sync_replay_videos(integer()) ::
          {:ok, %{found: [Replay.t()], missing: [Replay.t()], failed: [Replay.t()]}} | {:error, term()}
  def sync_replay_videos(session_id) do
    case session_id |> ListeningSession.get() |> ListeningSession.preload() do
      %ListeningSession{source: :album, user: %User{} = user, ended_at: %DateTime{}} = session ->
        results =
          user
          |> Profile.get([:video_settings, :replays], [])
          |> Enum.filter(&(status(slot(session.replays, &1.id) || %{}) in [nil, "pending", "exhausted"]))
          |> Enum.map(&{&1, find_replay_video(session, &1)})

        {:ok, found} =
          Repo.transaction(fn ->
            locked = lock_session(session_id)
            now = DateTime.utc_now(:second)

            {replays, found} =
              Enum.reduce(results, {locked.replays, []}, fn
                {replay, {:ok, %Video{} = video}}, {acc, found} ->
                  entry = slot(acc, replay.id) || %{}

                  if status(entry) in [nil, "pending", "exhausted"] do
                    cancel_job(entry)
                    {put_entry(found_entry(entry, replay, video, "auto", now), acc), [replay | found]}
                  else
                    {acc, found}
                  end

                _not_found, acc ->
                  acc
              end)

            locked |> ListeningSession.changeset(%{replays: replays}) |> Repo.update!()
            Enum.reverse(found)
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

  @doc """
  Saves the links edited by hand for the session `session_id`, as built by `manual_entry/2`.

  `entries` replace the links of the session (the entries that have a `url`), in that order. Slots still
  being looked for (no `url`) are kept. A link that carries the `replay_id` of a tracked slot settles it as
  `found` and cancels its job. A link that carried a tracked `replay_id` and no longer does (deleted, or
  moved to another replay) is unmarked like `unmark_upload/2`: the slot becomes `rejected` when it was an
  auto match, and goes back to `pending` otherwise.

  A replay can be linked once: it fails with `:duplicate_replay` when two entries carry the same `replay_id`,
  and with `:not_found` when the session is gone.
  """
  @spec save_links(integer(), [map()]) :: {:ok, ListeningSession.t()} | {:error, term()}
  def save_links(session_id, entries) do
    entries = Enum.reject(entries, &(String.trim(&1["url"] || "") == ""))
    replay_ids = for %{"replay_id" => replay_id} <- entries, is_binary(replay_id), do: replay_id

    if length(replay_ids) == length(Enum.uniq(replay_ids)),
      do: store_links(session_id, entries),
      else: {:error, :duplicate_replay}
  end

  defp store_links(session_id, entries) do
    Repo.transaction(fn ->
      case lock_session(session_id) do
        %ListeningSession{replays: current} = session ->
          slots = for %{"replay_id" => replay_id} = entry <- current, into: %{}, do: {replay_id, entry}
          claimed = for %{"replay_id" => replay_id} <- entries, is_binary(replay_id), into: MapSet.new(), do: replay_id

          links = Enum.map(entries, &link(&1, slots[&1["replay_id"]]))

          others =
            for {replay_id, entry} <- slots, not MapSet.member?(claimed, replay_id), reduce: [] do
              acc -> acc ++ List.wrap(release(entry, session_id))
            end

          session |> ListeningSession.changeset(%{replays: links ++ others}) |> Repo.update!()

        nil ->
          Repo.rollback(:not_found)
      end
    end)
  end

  defp link(entry, old) do
    base = if old && old["url"] == entry["url"], do: old, else: Map.drop(old || %{}, @video_fields)
    entry = Map.merge(base, entry)

    if tracked?(entry) and is_binary(entry["replay_id"]) do
      cancel_job(entry)
      mark_found(entry, DateTime.utc_now(:second))
    else
      entry
    end
  end

  defp release(%{"url" => url} = entry, session_id) when is_binary(url) do
    if tracked?(entry), do: unmark_entry(with_tracking(entry), session_id)
  end

  defp release(entry, _session_id), do: entry

  @doc """
  Forgets a replay that was deleted from the settings of the user `user_id`, in all their sessions.

  In each session that has entries for `replay_id`: the live job is cancelled, a slot still being looked for
  (no `url`) is removed, and a found slot becomes a plain link again (it keeps its video and loses its
  `replay_id` and tracking fields).
  """
  @spec forget_replay(integer(), String.t()) :: :ok
  def forget_replay(user_id, replay_id) do
    session_ids =
      Repo.all(
        from(s in ListeningSession,
          where: s.user_id == ^user_id,
          where: fragment("EXISTS (SELECT 1 FROM unnest(?) AS r WHERE r->>'replay_id' = ?)", s.replays, ^replay_id),
          select: s.id
        )
      )

    Enum.each(session_ids, fn session_id ->
      Repo.transaction(fn ->
        with %ListeningSession{replays: replays} = session <- lock_session(session_id) do
          replays = Enum.flat_map(replays, &forget_entry(&1, replay_id))
          session |> ListeningSession.changeset(%{replays: replays}) |> Repo.update!()
        end
      end)
    end)
  end

  defp forget_entry(%{"replay_id" => replay_id} = entry, replay_id) do
    cancel_job(entry)

    if is_binary(entry["url"]),
      do: [Map.drop(entry, ~w(replay_id status job_id due_at last_checked_at))],
      else: []
  end

  defp forget_entry(entry, _replay_id), do: [entry]

  @doc """
  Skips the replay `replay_id` of the session `session_id`: no more checks, and its live job is cancelled.

  Allowed from `pending`, `exhausted` and `rejected`.
  """
  @spec skip_upload(integer(), String.t()) :: {:ok, ListeningSession.t()} | {:error, term()}
  def skip_upload(session_id, replay_id) do
    update_upload(session_id, replay_id, fn _session, %{"status" => status} = entry ->
      if status in ~w(pending exhausted rejected),
        do: {:ok, close(entry, "skipped")},
        else: {:error, :invalid_transition}
    end)
  end

  @doc """
  Puts a `skipped` replay back to `pending`, with a new job starting again from the max iteration.
  """
  @spec unskip_upload(integer(), String.t()) :: {:ok, ListeningSession.t()} | {:error, term()}
  def unskip_upload(session_id, replay_id), do: revive_upload(session_id, replay_id, "skipped")

  @doc """
  Puts an `exhausted` replay back to `pending`, with a new job starting again from the max iteration.

  A `rejected` replay cannot be retried: it would likely match the same wrong video again.
  """
  @spec retry_upload(integer(), String.t()) :: {:ok, ListeningSession.t()} | {:error, term()}
  def retry_upload(session_id, replay_id), do: revive_upload(session_id, replay_id, "exhausted")

  @doc """
  Asks for one check of a `pending` replay, now.

  Inserts a `CheckUploadNowWorker` job, separate from the scheduled checks: it has no iteration and does not
  touch the schedule. See `check_upload_once/2`.
  """
  @spec check_upload_now(integer(), String.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def check_upload_now(session_id, replay_id) do
    case ListeningSession.get(session_id) do
      %ListeningSession{replays: replays} ->
        case slot(replays, replay_id) do
          %{"status" => "pending"} -> CheckUploadNowWorker.start(%{session_id: session_id, replay_id: replay_id})
          _ -> {:error, :invalid_transition}
        end

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Looks once for the video of a `pending` replay, whatever the schedule says.

  When the video is found, the slot becomes `found` and its scheduled job is cancelled. Otherwise only
  `last_checked_at` changes: no iteration is counted and no job is inserted, so the scheduled checks go on as
  planned. Returns what happened with the replay, and the session.

  Errors: `:not_found` (session or replay gone) and `:invalid_transition` (the replay is not `pending`).
  """
  @spec check_upload_once(integer(), String.t()) ::
          {:ok, {:found, Video.t()} | :not_found | {:error, term()}, Replay.t(), ListeningSession.t()} | {:error, term()}
  def check_upload_once(session_id, replay_id) do
    with %ListeningSession{user: %User{} = user} = session <- session_id |> ListeningSession.get() |> ListeningSession.preload(),
         %Replay{} = replay <- Enum.find(Profile.get(user, [:video_settings, :replays], []), &(&1.id == replay_id)),
         %{"status" => "pending"} <- slot(session.replays, replay_id) do
      result = find_replay_video(session, replay)
      now = DateTime.utc_now(:second)

      Repo.transaction(fn ->
        locked = lock_session(session_id)

        case slot(locked.replays, replay_id) do
          %{"status" => "pending"} = entry ->
            {entry, outcome} = once_outcome(entry, result, replay, now)
            updated = locked |> ListeningSession.changeset(%{replays: put_entry(entry, locked.replays)}) |> Repo.update!()
            {outcome, replay, updated}

          _ ->
            Repo.rollback(:invalid_transition)
        end
      end)
      |> case do
        {:ok, {outcome, replay, updated}} -> {:ok, outcome, replay, updated}
        {:error, _} = error -> error
      end
    else
      %{} -> {:error, :invalid_transition}
      _ -> {:error, :not_found}
    end
  end

  defp once_outcome(entry, {:ok, %Video{} = video}, replay, now) do
    cancel_job(entry)
    {found_entry(entry, replay, video, "auto", now), {:found, video}}
  end

  defp once_outcome(entry, result, _replay, now) do
    outcome = if result == {:error, :not_found}, do: :not_found, else: result
    {Map.put(entry, "last_checked_at", DateTime.to_iso8601(now)), outcome}
  end

  @doc """
  Marks the replay `replay_id` of the session `session_id` as uploaded, at the YouTube link `url`.

  The video must be public, on the YouTube channel of the replay, and not already attached to the session.
  It is stored with `source: "manual"`, the replay becomes `found` and its live job is cancelled. Allowed
  from `pending`, `exhausted` and `rejected`.

  Errors: `:invalid_url`, `:video_not_found` (unknown, or not public yet), `{:wrong_channel, title}` with the
  title of the channel the video is on, `:duplicate`, `:not_found` and `:invalid_transition`.
  """
  @spec attach_upload(integer(), String.t(), String.t()) :: {:ok, ListeningSession.t()} | {:error, term()}
  def attach_upload(session_id, replay_id, url) do
    with %ListeningSession{user: %User{} = user} <- session_id |> ListeningSession.get() |> ListeningSession.preload(),
         %Replay{channel_id: channel_id} = replay <-
           Enum.find(Profile.get(user, [:video_settings, :replays], []), &(&1.id == replay_id)),
         %Channel{youtube_channel_id: expected} <-
           Enum.find(Profile.get(user, [:video_settings, :channels], []), &(&1.id == channel_id)),
         {:ok, id} <- video_id(url),
         {:ok, %Video{privacy: :public} = video} <- lookup_video(id),
         :ok <- if(video.channel_id == expected, do: :ok, else: {:error, {:wrong_channel, video.channel_title}}) do
      update_upload(session_id, replay_id, fn session, %{"status" => status} = entry ->
        cond do
          status not in ~w(pending exhausted rejected) ->
            {:error, :invalid_transition}

          Enum.any?(session.replays, &(&1["video_id"] == video.id)) ->
            {:error, :duplicate}

          true ->
            cancel_job(entry)
            {:ok, found_entry(entry, replay, %{video | url: url}, "manual", DateTime.utc_now(:second))}
        end
      end)
    else
      {:error, _} = error -> error
      {:ok, %Video{}} -> {:error, :video_not_found}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Removes the video of a `found` replay.

  An `auto` match becomes `rejected`: it was wrong, and detection does not restart. A `manual` entry (a typo
  in the URL, say) goes back to `pending` with a new job.
  """
  @spec unmark_upload(integer(), String.t()) :: {:ok, ListeningSession.t()} | {:error, term()}
  def unmark_upload(session_id, replay_id) do
    update_upload(session_id, replay_id, fn session, entry ->
      if entry["status"] == "found",
        do: {:ok, unmark_entry(entry, session.id)},
        else: {:error, :invalid_transition}
    end)
  end

  defp unmark_entry(entry, session_id) do
    rest = Map.drop(entry, @video_fields)
    if entry["source"] == "auto", do: close(rest, "rejected"), else: revive(rest, session_id)
  end

  defp video_id(url) do
    case Video.id_from_url(url) do
      {:ok, _} = ok -> ok
      :error -> {:error, :invalid_url}
    end
  end

  defp lookup_video(id) do
    case Apis.youtube().get_video(id) do
      {:ok, %Video{}} = ok -> ok
      {:error, _} -> {:error, :video_not_found}
    end
  end

  defp revive_upload(session_id, replay_id, from) do
    update_upload(session_id, replay_id, fn session, entry ->
      if entry["status"] == from,
        do: {:ok, revive(entry, session.id)},
        else: {:error, :invalid_transition}
    end)
  end

  # Locks the session, hands it and the slot of `replay_id` (with its tracking fields filled in) to `fun`, and
  # writes back the entry it returns.
  defp update_upload(session_id, replay_id, fun) do
    Repo.transaction(fn ->
      with %ListeningSession{replays: replays} = session <- lock_session(session_id),
           %{} = entry <- slot(replays, replay_id),
           entry = with_tracking(entry),
           {:ok, entry} <- fun.(session, entry) do
        session |> ListeningSession.changeset(%{replays: put_entry(entry, replays)}) |> Repo.update!()
      else
        {:error, reason} -> Repo.rollback(reason)
        nil -> Repo.rollback(:not_found)
      end
    end)
  end

  # An entry linked without any tracking (no `status`) is a `found` slot: give it the fields the actions use.
  defp with_tracking(entry) do
    case status(entry) do
      nil -> entry
      status -> tracking_defaults() |> Map.merge(entry) |> Map.put("status", status)
    end
  end

  defp close(entry, status) do
    cancel_job(entry)
    Map.merge(entry, %{"status" => status, "job_id" => nil})
  end

  defp revive(entry, session_id) do
    {:ok, job} = CheckUploadWorker.start(%{session_id: session_id, replay_id: entry["replay_id"], iteration: max_iterations()})
    Map.merge(entry, %{"status" => "pending", "job_id" => job.id})
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
