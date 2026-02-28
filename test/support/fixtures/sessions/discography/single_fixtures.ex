defmodule PremiereEcoute.Discography.SingleFixtures do
  @moduledoc """
  Single fixtures.

  Provides factory functions to generate test Single structs for use in test suites.
  """

  alias PremiereEcoute.Discography.Single

  @doc """
  Generates test Single struct with default attributes.
  """
  @spec single_fixture(map()) :: Single.t()
  def single_fixture(attrs \\ %{}) do
    %{
      provider: :spotify,
      track_id: "track123",
      name: "Sample Track",
      artist: "Sample Artist",
      duration_ms: 210_000,
      cover_url: "http://example.com/cover.jpg"
    }
    |> Map.merge(attrs)
    |> then(fn attrs -> struct(Single, attrs) end)
  end
end
