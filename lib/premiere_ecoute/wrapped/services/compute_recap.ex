defmodule PremiereEcoute.Wrapped.Services.ComputeRecap do
  @moduledoc """
  Computes the recap of a viewer for a year, now or in the background.

  The public replay shows the same cards as the viewer sees.
  """

  import Ecto.Query, only: [from: 2]

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.PubSub
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Wrapped.Listens
  alias PremiereEcoute.Wrapped.Recap
  alias PremiereEcoute.Wrapped.Services.BuildCards
  alias PremiereEcoute.Wrapped.Workers

  @doc "PubSub topic notified with `{:wrapped_computed, recap}` when the recap of a user is ready."
  @spec topic(User.t()) :: String.t()
  def topic(%User{id: id}), do: "wrapped:#{id}"

  @doc """
  Computes and stores the recap of a user for a year, replacing the previous one.

  A viewer below the minimum number of albums gets a recap without cards.
  """
  @spec compute(User.t(), integer()) :: {:ok, Recap.t()} | {:error, Ecto.Changeset.t()}
  def compute(%User{} = user, year) do
    cards = user |> Listens.all(year) |> BuildCards.cards()
    attrs = %{cards: cards, version: Recap.version(), computed_at: DateTime.utc_now(:second)}

    with {:ok, recap} <- Recap.store(user.id, year, attrs) do
      recap = Recap.get(recap.id)
      PubSub.broadcast(topic(user), {:wrapped_computed, recap})
      {:ok, recap}
    end
  end

  @doc "Enqueues the computation of the recap of a user."
  @spec request(User.t(), integer()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def request(%User{id: id}, year), do: Workers.ComputeRecap.now(%{user_id: id, year: year})

  @doc "Counts the recap computations waiting, running or about to be retried."
  @spec pending() :: integer()
  def pending do
    query = from(j in Oban.Job, where: j.queue == "wrapped" and j.state in ~w(available scheduled executing retryable))

    PremiereEcoute.Repo.aggregate(query, :count, prefix: "oban")
  end

  @doc """
  Enqueues the computation of the recap of a user if the running campaign has none for them yet.

  Meant to be called when a user shows up: it makes the recap of a newcomer ready within moments instead of waiting for the daily job.
  """
  @spec ensure(User.t()) :: :ok
  def ensure(%User{} = user) do
    with year when not is_nil(year) <- Recap.campaign_year(),
         nil <- Recap.current(user, year) do
      request(user, year)
    end

    :ok
  end

  @doc "Enqueues the computation of the recap of every user who voted on an album or a single during a year, at low priority."
  @spec schedule(integer()) :: :ok
  def schedule(year), do: year |> Sessions.list_voter_ids() |> enqueue(year)

  @doc "Same as `schedule/1`, for the users who have no recap of the year yet."
  @spec schedule_missing(integer()) :: :ok
  def schedule_missing(year) do
    done = MapSet.new(Recap.user_ids(year))

    year |> Sessions.list_voter_ids() |> Enum.reject(&MapSet.member?(done, &1)) |> enqueue(year)
  end

  # Priority 9 lets the recap of a user waiting on the page (priority 0) go ahead of a batch
  defp enqueue(user_ids, year) do
    Enum.each(user_ids, &Workers.ComputeRecap.start(%{user_id: &1, year: year}, priority: 9))
  end
end
