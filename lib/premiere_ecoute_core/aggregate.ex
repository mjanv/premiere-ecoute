defmodule PremiereEcouteCore.Aggregate do
  @moduledoc """
  Base module for aggregate roots and entities.

  Provides comprehensive CRUD operations, pagination, preloading, statistics, and JSON encoding for domain aggregates using Ecto. Aggregates are configured with root associations for preloading, identity fields for uniqueness checks, and JSON fields for serialization.

  ## Options

  - `:root` - List of associations to preload automatically
  - `:identity` - Fields used to uniquely identify entities
  - `:json` - Fields to include in JSON encoding

  ## Available Operations

  ### Forms

  - `form/2` - Create a changeset form

  ### Create

  - `create/1` - Insert new entity with preload
  - `create_if_not_exists/1` - Insert only if not already exists
  - `create_all/2` - Bulk insert entities

  ### Read

  - `get/1` - Fetch by ID with preload
  - `get_by/2` - Fetch by clauses with preload
  - `exists?/1` - Check if entity exists
  - `all/1` - Fetch all with optional filtering
  - `all_by/2` - Fetch all matching clauses
  - `page/3` - Paginated query
  - `next_page/2` - Fetch next page in pagination

  ### Update

  - `update/2` - Update entity with preload
  - `upsert/2` - Insert or update entity

  ### Delete

  - `delete/1` - Delete entity
  - `delete_all/1` - Delete all matching query

  ### Statistics

  - `average/2`, `count/2`, `max/2`, `min/2`, `sum/2` - Aggregate functions
  """

  @doc """
  Injects aggregate functionality into the using module.

  Generates CRUD operations, pagination, statistics, and JSON encoding. Accepts :root for preloading associations, :identity for uniqueness checks, and :json for serialization fields.
  """
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(opts) do
    root = Keyword.get(opts, :root, [])
    identity = Keyword.get(opts, :identity, [])
    json = Keyword.get(opts, :json, [])

    quote do
      use Ecto.Schema

      import Ecto.Changeset
      import Ecto.Query

      alias PremiereEcoute.Events.Store
      alias PremiereEcoute.Repo

      @type entity(type) :: type | nil | Ecto.Association.NotLoaded.t()
      @type nullable(type) :: type | nil

      # Forms
      @doc "Creates changeset form from entity and attributes"
      @spec form(t(), map()) :: Ecto.Changeset.t()
      def form(entity, attrs \\ %{}), do: changeset(entity, attrs)

      # Preload
      @type entity() :: [Ecto.Schema.t()] | Ecto.Schema.t() | nil

      @doc false
      @spec preload(entity() | {:ok, entity()} | {:error, any()}) :: entity() | {:ok, entity()} | {:error, any()}
      def preload({:ok, entity}), do: {:ok, preload(entity)}
      def preload({:error, reason}), do: {:error, reason}
      def preload(entity), do: Repo.preload(entity, unquote(root), force: true)

      # Create operations
      @doc false
      @spec create(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
      def create(entity) when is_struct(entity), do: create(Map.from_struct(entity))

      @doc "Inserts new entity with preloaded associations"
      @spec create(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
      def create(attrs), do: preload(Repo.insert(changeset(struct(__MODULE__), attrs)))

      @doc "Inserts entity only if it doesn't exist based on identity fields"
      @spec create_if_not_exists(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
      def create_if_not_exists(entity) do
        case get_by(Map.take(entity, unquote(identity))) do
          nil -> create(entity)
          entity -> {:ok, entity}
        end
      end

      @doc "Bulk inserts multiple entities"
      @spec create_all([map()], keyword()) :: {:ok, any()} | {:error, any()}
      def create_all(entities, opts) do
        Ecto.Multi.new()
        |> Ecto.Multi.insert_all(:all, __MODULE__, entities, opts)
        |> Repo.transact()
      end

      # Read operations
      @doc "Fetches entity by ID with preloaded associations"
      def get(id), do: preload(Repo.get(__MODULE__, id))

      @doc "Fetches entity by query clauses with preloaded associations"
      def get_by(query \\ __MODULE__, clauses), do: preload(Repo.get_by(query, clauses))

      @doc "Checks if entity exists based on identity fields"
      def exists?(entity), do: !is_nil(get_by(Map.take(entity, unquote(identity))))

      @doc "Fetches all entities matching clauses"
      def all(clauses \\ []), do: Repo.all(all_query(clauses))

      @doc "Fetches all entities matching query and clauses"

      def all_by(query \\ __MODULE__, clauses), do: preload(Repo.all_by(query, clauses))

      @doc "Fetches paginated entities"
      def page(clauses \\ [], page, page_size \\ 1),
        do: Repo.paginate(all_query(clauses), page: page, page_size: page_size)

      @doc "Fetches next page of results"
      def next_page(clauses \\ [], page)

      @doc false
      def next_page(clauses, %Phoenix.LiveView.AsyncResult{result: page}), do: next_page(clauses, page)

      @doc false
      def next_page(clauses, %Scrivener.Page{page_number: page_number, total_pages: page_number} = page),
        do: page

      @doc false
      def next_page(clauses, %Scrivener.Page{page_number: page_number, page_size: page_size}),
        do: page(clauses, page_number + 1, page_size)

      defp all_query(clauses \\ []) do
        __MODULE__
        |> where(^Keyword.get(clauses, :where, true))
        |> order_by(^Keyword.get(clauses, :order_by, asc: :updated_at))
        |> preload(unquote(root))
      end

      # Update operations
      @doc "Updates entity with attributes"
      def update(entity, attrs), do: preload(Repo.update(changeset(entity, attrs)))

      @doc "Inserts or updates entity"
      def upsert(entity, attrs), do: preload(Repo.insert_or_update(changeset(entity, attrs)))

      # Delete operations
      @doc "Deletes entity"
      def delete(entity), do: Repo.delete(changeset(entity, %{}), allow_stale: true)

      @doc "Deletes all entities matching query"
      def delete_all(query \\ __MODULE__), do: Repo.delete_all(query)

      # Statistics
      @doc "Calculates average of field across query results"
      def average(query \\ __MODULE__, field), do: Repo.aggregate(query, :avg, field)

      @doc "Counts entities matching query"
      def count(query \\ __MODULE__, field), do: Repo.aggregate(query, :count, field)

      @doc "Finds maximum value of field across query results"
      def max(query \\ __MODULE__, field), do: Repo.aggregate(query, :max, field)

      @doc "Finds minimum value of field across query results"
      def min(query \\ __MODULE__, field), do: Repo.aggregate(query, :min, field)

      @doc "Calculates sum of field across query results"
      def sum(query \\ __MODULE__, field), do: Repo.aggregate(query, :sum, field)

      defoverridable create: 1, get: 1, update: 2, upsert: 2, delete: 1, delete_all: 1

      defimpl Jason.Encoder, for: __MODULE__ do
        def encode(entity, opts) do
          Jason.Encode.map(Map.take(entity, unquote(json)), opts)
        end
      end
    end
  end
end
