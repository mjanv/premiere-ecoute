defmodule PremiereEcoute.Core.Schema do
  @moduledoc false

  defmacro __using__(opts) do
    preload = Keyword.get(opts, :preload, [])

    quote do
      use Ecto.Schema

      import Ecto.Changeset
      import Ecto.Query

      alias PremiereEcoute.Repo

      # Pipeline
      def preload(structs_or_struct_or_nil) do
        Repo.preload(structs_or_struct_or_nil, unquote(preload), force: true)
      end

      # Create operations
      def create(entity) do
        __MODULE__
        |> struct()
        |> changeset(Map.from_struct(entity))
        |> Repo.insert()
      end

      # Read operations
      def get(id), do: preload(Repo.get(__MODULE__, id))
      def get_by(clauses), do: preload(Repo.get_by(__MODULE__, clauses))
      def all, do: preload(Repo.all(__MODULE__))
      def all_by(clauses), do: preload(Repo.all_by(__MODULE__, clauses))

      # Update operations
      @spec update(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
      def update(entity, attrs) do
        entity
        |> changeset(attrs)
        |> Repo.update()
      end

      # Delete operations
      def delete(id) do
        case Repo.get(__MODULE__, id) do
          nil ->
            :error

          entity ->
            Repo.delete(entity)
            :ok
        end
      end

      def delete_all, do: Repo.delete_all(__MODULE__)

      # Statistics
      def average(field), do: Repo.aggregate(__MODULE__, :avg, field)
      def average(query, field), do: Repo.aggregate(query, :avg, field)
      def count(field), do: Repo.aggregate(__MODULE__, :count, field)
      def count(query, field), do: Repo.aggregate(query, :count, field)
      def max(field), do: Repo.aggregate(__MODULE__, :max, field)
      def max(query, field), do: Repo.aggregate(query, :max, field)
      def min(field), do: Repo.aggregate(__MODULE__, :min, field)
      def sum(field), do: Repo.aggregate(__MODULE__, :sum, field)

      def min(query, field), do: Repo.aggregate(query, :min, field)
      def sum(query, field), do: Repo.aggregate(query, :sum, field)

      defoverridable preload: 1, create: 1, update: 2, delete: 1
    end
  end
end
