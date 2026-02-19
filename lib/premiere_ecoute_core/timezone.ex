defmodule PremiereEcouteCore.Timezone do
  @moduledoc """
  Timezone utilities.

  Wraps Timex timezone lookups for validation and listing.
  """

  @doc "Returns true if the given timezone string is valid."
  @spec exists?(String.t()) :: boolean()
  def exists?(tz), do: Timex.Timezone.exists?(tz)

  @doc "Returns a sorted list of all valid IANA timezone names."
  @spec list() :: [String.t()]
  def list, do: Timex.timezones() |> Enum.sort()
end
