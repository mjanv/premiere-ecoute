defmodule PremiereEcoute.Apis.SpotifyApi.Parser do
  @moduledoc """
  Spotify API response parser.

  Parses Spotify API responses extracting artist names, release dates, and album cover URLs.
  """

  @doc """
  Extracts primary artist name from Spotify artists array.

  Returns first artist's name or "Unknown Artist" if array is empty or invalid.
  """
  @spec parse_primary_artist(list(map()) | any()) :: String.t()
  def parse_primary_artist([%{"name" => name} | _]), do: name
  def parse_primary_artist(_), do: "Unknown Artist"

  @doc """
  Parses Spotify release date string into Date.

  Handles year-only, year-month, and full date formats. Returns nil for empty or nil values.
  """
  @spec parse_release_date(String.t() | nil) :: Date.t() | nil
  def parse_release_date(nil), do: nil
  def parse_release_date(""), do: nil

  def parse_release_date(date_string) do
    case String.split(date_string, "-") do
      [year] -> Date.from_iso8601!("#{year}-01-01")
      [year, month] -> Date.from_iso8601!("#{year}-#{month}-01")
      [year, month, day] -> Date.from_iso8601!("#{year}-#{month}-#{day}")
    end
  end

  @doc """
  Extracts album cover URL from Spotify images array.

  Prefers medium-sized images (250-350px height). Falls back to first available image or nil.
  """
  @spec parse_album_cover_url(list(map()) | any()) :: String.t() | nil
  def parse_album_cover_url(images) when is_list(images) do
    medium = Enum.find(images, fn img -> (img["height"] || 0) >= 250 && (img["height"] || 0) <= 350 end)

    case medium || List.first(images) do
      %{"url" => url} -> url
      _ -> nil
    end
  end

  def parse_album_cover_url(_), do: nil
end
