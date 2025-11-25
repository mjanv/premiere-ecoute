defmodule PremiereEcoute.Discography.Isrc do
  @moduledoc """
  ISRC (International Standard Recording Code) parser.

  Parses ISRC codes into prefix, year, and designation components for music track identification.
  """

  defstruct [:prefix, :year, :designation]

  def parse(string) do
    case String.replace(string, "-", "") do
      <<prefix::binary-size(5), year::binary-size(2), designation::binary-size(5)>> ->
        case Integer.parse(year) do
          {year, ""} -> {:ok, %__MODULE__{prefix: prefix, year: 2000 + year, designation: designation}}
          _ -> {:error, nil}
        end

      _ ->
        {:error, nil}
    end
  end
end
