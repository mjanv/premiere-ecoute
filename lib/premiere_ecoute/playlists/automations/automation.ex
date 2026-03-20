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
    json: [:id, :user_id, :name, :schedule_type, :enabled]

  alias Crontab.CronExpression
  alias PremiereEcoute.Accounts.User

  @schedule_types [:manual, :once, :recurring]

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          user: entity(User.t()),
          name: String.t() | nil,
          description: String.t() | nil,
          enabled: boolean(),
          schedule_type: :manual | :once | :recurring | nil,
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
    field :schedule_type, Ecto.Enum, values: @schedule_types
    field :cron_expression, :string
    # AIDEV-NOTE: steps is a plain jsonb array; each element is a map with
    # position (integer), action_type (string), config (map)
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
    |> cast(attrs, [:user_id, :name, :description, :enabled, :schedule_type, :cron_expression, :steps])
    |> validate_required([:user_id, :name, :schedule_type])
    |> validate_inclusion(:schedule_type, @schedule_types)
    |> validate_cron_expression()
    |> foreign_key_constraint(:user_id)
  end

  @doc "Inserts a new automation for the given user."
  @spec insert(User.t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def insert(%User{id: id}, attrs) do
    %__MODULE__{}
    |> changeset(Map.put(attrs, "user_id", id))
    |> Repo.insert()
  end

  @doc "Updates an existing automation."
  @spec update(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def update(%__MODULE__{} = automation, attrs) do
    automation
    |> changeset(attrs)
    |> Repo.update()
  end

  @doc "Lists all automations for a user, most recently updated first."
  @spec list_for_user(User.t()) :: [t()]
  def list_for_user(%User{id: id}) do
    __MODULE__
    |> where([a], a.user_id == ^id)
    |> order_by([a], desc: a.updated_at)
    |> Repo.all()
  end

  defp validate_cron_expression(changeset) do
    case get_field(changeset, :schedule_type) do
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
