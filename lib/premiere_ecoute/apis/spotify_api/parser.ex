defmodule PremiereEcoute.Apis.SpotifyApi.Parser do
  @moduledoc false

  def parse_primary_artist(artists) when is_list(artists) do
    case List.first(artists) do
      %{"name" => name} -> name
      _ -> "Unknown Artist"
    end
  end

  def parse_primary_artist(_), do: "Unknown Artist"

  def parse_release_date(nil), do: nil
  def parse_release_date(""), do: nil

  def parse_release_date(date_string) do
    case String.split(date_string, "-") do
      [year] -> Date.from_iso8601!("#{year}-01-01")
      [year, month] -> Date.from_iso8601!("#{year}-#{month}-01")
      [year, month, day] -> Date.from_iso8601!("#{year}-#{month}-#{day}")
    end
  end

  def parse_album_cover_url(images) when is_list(images) do
    # Get the medium-sized image (usually 300x300)
    medium_image =
      Enum.find(images, fn img ->
        (img["height"] || 0) >= 250 && (img["height"] || 0) <= 350
      end)

    case medium_image || List.first(images) do
      %{"url" => url} -> url
      _ -> nil
    end
  end

  def parse_album_cover_url(_), do: nil
end
