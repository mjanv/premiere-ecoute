defmodule PremiereEcoute.Playlists.Automations.AutomationRun do
  @moduledoc """
  Schema for automation_runs table.

  Each record represents a single execution of an automation. Steps are
  snapshotted from the automation at run start so history remains readable
  after the automation's steps are edited.
  """

  use PremiereEcouteCore.Aggregate,
    json: [:id, :automation_id, :status, :trigger, :started_at, :finished_at]

  alias PremiereEcoute.Playlists.Automations.Automation

  @statuses [:running, :completed, :failed]
  @triggers [:manual, :scheduled]

  @type t :: %__MODULE__{
          id: integer() | nil,
          automation_id: integer() | nil,
          automation: entity(Automation.t()),
          oban_job_id: integer() | nil,
          status: :running | :completed | :failed | nil,
          trigger: :manual | :scheduled | nil,
          steps: [map()],
          started_at: DateTime.t() | nil,
          finished_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "automation_runs" do
    field :oban_job_id, :integer
    field :status, Ecto.Enum, values: @statuses
    field :trigger, Ecto.Enum, values: @triggers
    # AIDEV-NOTE: steps snapshot from automation at run start; each element has
    # position, action_type, status, output, error, started_at, finished_at
    field :steps, {:array, :map}, default: []
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime

    belongs_to :automation, Automation

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating an automation run."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(run, attrs) do
    run
    |> cast(attrs, [:automation_id, :oban_job_id, :status, :trigger, :steps, :started_at, :finished_at])
    |> validate_required([:automation_id, :oban_job_id, :status, :trigger])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:trigger, @triggers)
    |> foreign_key_constraint(:automation_id)
  end

  @doc "Inserts a new run record."
  @spec insert(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def insert(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a run record (status, steps, finished_at)."
  @spec update(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def update(%__MODULE__{} = run, attrs) do
    run
    |> changeset(attrs)
    |> Repo.update()
  end

  @doc "Lists runs for an automation, most recent first."
  @spec list_for_automation(Automation.t()) :: [t()]
  def list_for_automation(%Automation{id: id}) do
    __MODULE__
    |> where([r], r.automation_id == ^id)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc "Deletes runs older than the given cutoff. Returns deleted count."
  @spec delete_before(DateTime.t()) :: non_neg_integer()
  def delete_before(cutoff) do
    {deleted, _} =
      __MODULE__
      |> where([r], r.inserted_at < ^cutoff)
      |> Repo.delete_all()

    deleted
  end
end
