defmodule PremiereEcouteCore.Ecto.Map do
  @moduledoc """
  Ecto type for maps whose keys are atomized on load/cast.

  Backs `provider_ids` (`:spotify`, `:deezer`, `:tidal`, `:youtube`), which callers read
  with atom keys. Keys are converted with `String.to_existing_atom/1`, not `String.to_atom/1`:
  the value partly originates from external API payloads, and unbounded atom creation is a
  memory-exhaustion vector (atoms are never garbage-collected). An unknown key raises rather
  than minting a new atom.
  """

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
