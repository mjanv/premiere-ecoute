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
      def form(entity, attrs \\ %{}), do: changeset(entity, attrs)

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

      def create_all(entities, opts) do
        Ecto.Multi.new()
        |> Ecto.Multi.insert_all(:all, __MODULE__, entities, opts)
        |> Repo.transact()
      end

      # Read operations
      def get(id), do: preload(Repo.get(__MODULE__, id))
      def get_by(query \\ __MODULE__, clauses), do: preload(Repo.get_by(query, clauses))
      def exists?(entity), do: !is_nil(get_by(Map.take(entity, unquote(identity))))
      def all(clauses \\ []), do: Repo.all(all_query(clauses))
      def all_by(query \\ __MODULE__, clauses), do: preload(Repo.all_by(query, clauses))
      def page(clauses \\ [], page, page_size \\ 1), do: Repo.paginate(all_query(clauses), page: page, page_size: page_size)
      def next_page(clauses \\ [], page)
      def next_page(clauses, %Phoenix.LiveView.AsyncResult{result: page}), do: next_page(clauses, page)
      def next_page(clauses, %Scrivener.Page{page_number: page_number, total_pages: page_number} = page), do: page

      def next_page(clauses, %Scrivener.Page{page_number: page_number, page_size: page_size}),
        do: page(clauses, page_number + 1, page_size)

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

      defoverridable create: 1, get: 1, update: 2, upsert: 2, delete: 1, delete_all: 1

      defimpl Jason.Encoder, for: __MODULE__ do
        def encode(entity, opts) do
          Jason.Encode.map(Map.take(entity, unquote(json)), opts)
        end
      end
    end
  end
end
