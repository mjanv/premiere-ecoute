defmodule PremiereEcouteCore.Ecto.Map do
  @moduledoc false

  use Ecto.Type

  def type, do: :map

  def cast(map) when is_map(map) do
    {:ok, to_atom(map)}
  end

  def cast(_), do: :error

  def dump(map) when is_map(map) do
    {:ok, map}
  end

  def dump(_), do: :error

  def load(map) when is_map(map) do
    {:ok, to_atom(map)}
  end

  def load(_), do: :error

  defp to_atom(m) when is_map(m), do: Map.new(m, fn {k, v} -> {to_atom(k), v} end)
  defp to_atom(a) when is_atom(a), do: a
  defp to_atom(b) when is_binary(b), do: String.to_existing_atom(b)
end
