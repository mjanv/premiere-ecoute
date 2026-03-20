defmodule PremiereEcoute.Playlists.Automations.Automation do
  @moduledoc """
  Schema for playlist_automations table.

  An automation is an ordered list of steps that run sequentially against the
  Spotify API. Steps are stored as a jsonb array; each element has `position`,
  `action_type`, and `config` keys.

  `next_run_at` and `last_run_at` are virtual fields populated by the
  `Automations` context when loading automations for display.
  """

  use PremiereEcouteCore.Aggregate,
    json: [:id, :user_id, :name, :schedule, :enabled]

  alias Crontab.CronExpression
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Playlists.Automations.AutomationRun

  @schedules [:manual, :once, :recurring]

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          user: entity(User.t()),
          name: String.t() | nil,
          description: String.t() | nil,
          enabled: boolean(),
          schedule: :manual | :once | :recurring | nil,
          scheduled_at: DateTime.t() | nil,
          cron_expression: String.t() | nil,
          steps: [map()],
          next_run_at: DateTime.t() | nil,
          last_run_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "playlist_automations" do
    field :name, :string
    field :description, :string
    field :enabled, :boolean, default: true
    field :schedule, Ecto.Enum, values: @schedules
    field :scheduled_at, :utc_datetime
    field :cron_expression, :string
    field :steps, {:array, :map}, default: []

    field :next_run_at, :utc_datetime, virtual: true
    field :last_run_at, :utc_datetime, virtual: true

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating or updating an automation."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(automation, attrs) do
    automation
    |> cast(attrs, [:user_id, :name, :description, :enabled, :schedule, :scheduled_at, :cron_expression, :steps])
    |> validate_required([:user_id, :name, :schedule])
    |> validate_inclusion(:schedule, @schedules)
    |> validate_cron_expression()
    |> foreign_key_constraint(:user_id)
  end

  @doc "Inserts a new automation for the given user."
  @spec insert(User.t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def insert(%User{id: id}, attrs) do
    # AIDEV-NOTE: stringify all keys to avoid mixed atom/string key crash in Ecto.Changeset.cast
    attrs =
      attrs
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Map.new()
      |> Map.put("user_id", id)

    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates an existing automation."
  @spec update(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def update(%__MODULE__{} = automation, attrs) do
    automation
    |> changeset(attrs)
    |> Repo.update()
  end

  @doc "Lists all automations for a user with virtual fields populated, most recently updated first."
  @spec list_for_user(User.t()) :: [t()]
  def list_for_user(%User{id: id}) do
    with_virtual_fields_query()
    |> where([a], a.user_id == ^id)
    |> order_by([a], desc: a.updated_at)
    |> Repo.all()
  end

  @doc "Gets a single automation by id with virtual fields populated."
  @spec get_with_virtual_fields(User.t(), t()) :: t() | nil
  def get_with_virtual_fields(%User{} = user, id) when is_integer(id) do
    get_with_virtual_fields(user, %__MODULE__{id: id})
  end

  def get_with_virtual_fields(%User{id: user_id}, %__MODULE__{id: id}) do
    with_virtual_fields_query()
    |> where([a], a.user_id == ^user_id and a.id == ^id)
    |> Repo.one()
  end

  # AIDEV-NOTE: subqueries for last_run_at/next_run_at avoid N+1; used by both list and get
  defp with_virtual_fields_query do
    worker = "PremiereEcoute.Playlists.Automations.Workers.AutomationRunWorker"

    last_run_subquery =
      AutomationRun
      |> group_by([r], r.automation_id)
      |> select([r], %{automation_id: r.automation_id, last_run_at: max(r.inserted_at)})

    next_run_subquery =
      Oban.Job
      |> where([j], j.worker == ^worker and j.state in ["scheduled", "available"])
      |> group_by([j], fragment("(?->>'automation_id')::bigint", j.args))
      |> select([j], %{
        automation_id: fragment("(?->>'automation_id')::bigint", j.args),
        next_run_at: min(j.scheduled_at)
      })

    __MODULE__
    |> join(:left, [a], lr in subquery(last_run_subquery), on: lr.automation_id == a.id)
    |> join(:left, [a], nr in subquery(next_run_subquery), on: nr.automation_id == a.id, prefix: "oban")
    |> select([a, lr, nr], %{a | last_run_at: lr.last_run_at, next_run_at: nr.next_run_at})
  end

  defp validate_cron_expression(changeset) do
    case get_field(changeset, :schedule) do
      :recurring ->
        validate_change(changeset, :cron_expression, fn _field, expr ->
          case CronExpression.Parser.parse(expr || "") do
            {:ok, _} -> []
            {:error, _} -> [cron_expression: "is not a valid cron expression"]
          end
        end)

      _ ->
        changeset
    end
  end
end
