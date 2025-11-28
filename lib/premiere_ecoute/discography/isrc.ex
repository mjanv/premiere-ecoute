defmodule PremiereEcoute.Discography.Isrc do
  @moduledoc """
  ISRC (International Standard Recording Code) parser.

  Parses ISRC codes into prefix, year, and designation components for music track identification.
  """

  @type t :: %__MODULE__{
          prefix: String.t() | nil,
          year: integer() | nil,
          designation: String.t() | nil
        }

  defstruct [:prefix, :year, :designation]

  @doc """
  Parses an ISRC code string into structured components.

  Extracts 5-character prefix, 2-digit year (converted to full year by adding 2000), and 5-character designation. Removes hyphens before parsing.
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, nil}
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
