defmodule PremiereEcoute.Core.Aggregate do
  @moduledoc false

  defmacro __using__(opts) do
    root = Keyword.get(opts, :root, [])
    identity = Keyword.get(opts, :identity, [])
    json = Keyword.get(opts, :json, [])
    no_json = Keyword.get(opts, :no_json, [])

    encoder_opts = if Enum.empty?(json), do: [except: [:__meta__, :__struct__] ++ no_json], else: [only: json]

    quote do
      use Ecto.Schema

      import Ecto.Changeset
      import Ecto.Query

      alias PremiereEcoute.EventStore
      alias PremiereEcoute.Repo

      @derive {Jason.Encoder, unquote(encoder_opts)}
      # @derive {Inspect, expect: []}

      @type entity(type) :: type | nil | Ecto.Association.NotLoaded.t()
      @type nullable(type) :: type | nil

      # Preload
      def preload({:ok, entity}), do: {:ok, preload(entity)}
      def preload({:error, reason}), do: {:error, reason}
      def preload(entity), do: Repo.preload(entity, unquote(root), force: true)

      # Create operations
      def create(entity) when is_struct(entity), do: create(Map.from_struct(entity))
      def create(attrs), do: preload(Repo.insert(changeset(struct(__MODULE__), attrs)))

      def create_if_not_exists(entity) do
        case get_by(Map.take(entity, unquote(identity))) do
          nil -> create(entity)
          entity -> {:ok, entity}
        end
      end

      # Read operations
      def get(id), do: preload(Repo.get(__MODULE__, id))
      def get_by(query \\ __MODULE__, clauses), do: preload(Repo.get_by(query, clauses))
      def all(clauses \\ []), do: Repo.all(all_query(clauses))
      def all_by(query \\ __MODULE__, clauses), do: preload(Repo.all_by(query, clauses))

      def page(clauses \\ [], page, page_size \\ 1),
        do: Repo.paginate(all_query(clauses), page: page, page_size: page_size)

      defp all_query(clauses \\ []) do
        __MODULE__
        |> where(^Keyword.get(clauses, :where, true))
        |> order_by(^Keyword.get(clauses, :order_by, asc: :updated_at))
        |> preload(unquote(root))
      end

      # Update operations
      def update(entity, attrs), do: preload(Repo.update(changeset(entity, attrs)))
      def upsert(entity, attrs), do: preload(Repo.insert_or_update(changeset(entity, attrs)))

      # Delete operations
      def delete(entity), do: Repo.delete(changeset(entity, %{}), allow_stale: true)
      def delete_all(query \\ __MODULE__), do: Repo.delete_all(query)

      # Statistics
      def average(query \\ __MODULE__, field), do: Repo.aggregate(query, :avg, field)
      def count(query \\ __MODULE__, field), do: Repo.aggregate(query, :count, field)
      def max(query \\ __MODULE__, field), do: Repo.aggregate(query, :max, field)
      def min(query \\ __MODULE__, field), do: Repo.aggregate(query, :min, field)
      def sum(query \\ __MODULE__, field), do: Repo.aggregate(query, :sum, field)

      defoverridable create: 1, get: 1, update: 2, upsert: 2, delete: 1
    end
  end
end
