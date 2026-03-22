defmodule PremiereEcoute.Apis.MusicProvider.TidalApi.Parser do
  @moduledoc """
  Tidal API response parser.

  Parses Tidal v2 JSON:API responses: ISO 8601 durations, release dates,
  artwork files, and cover URL selection.
  """

  alias PremiereEcoute.Discography.Artist.Image

  @doc """
  Parses ISO 8601 duration string into milliseconds.

  Handles PT[H]H[M]M[S]S format. Returns 0 for nil or unparseable values.

  ## Examples

      iex> parse_duration_ms("PT5M38S")
      338_000

      iex> parse_duration_ms("PT1H2M3S")
      3_723_000

      iex> parse_duration_ms("PT51S")
      51_000
  """
  @spec parse_duration_ms(String.t() | nil) :: non_neg_integer()
  def parse_duration_ms(nil), do: 0

  def parse_duration_ms(duration) do
    hours = parse_component(duration, ~r/(\d+)H/)
    minutes = parse_component(duration, ~r/(\d+)M/)
    seconds = parse_component(duration, ~r/(\d+)S/)

    (hours * 3600 + minutes * 60 + seconds) * 1_000
  end

  @doc """
  Parses Tidal release date string into Date.

  Handles YYYY-MM-DD format. Returns nil for nil input.
  """
  @spec parse_release_date(String.t() | nil) :: Date.t() | nil
  def parse_release_date(nil), do: nil
  def parse_release_date(""), do: nil
  def parse_release_date(date_string), do: Date.from_iso8601!(date_string)

  @doc """
  Parses Tidal artwork files into Artist.Image structs.

  Finds the artwork matching artwork_id in the included list, then maps its files.
  Returns empty list if artwork not found.
  """
  @spec parse_artworks(list(map()), String.t() | nil) :: [Image.t()]
  def parse_artworks(_included, nil), do: []

  def parse_artworks(included, artwork_id) do
    case Enum.find(included, &(&1["id"] == artwork_id && &1["type"] == "artworks")) do
      nil ->
        []

      artwork ->
        artwork
        |> get_in(["attributes", "files"])
        |> Enum.map(fn file ->
          %Image{
            url: file["href"],
            width: file["meta"]["width"],
            height: file["meta"]["height"]
          }
        end)
    end
  end

  @doc """
  Picks the best cover URL from a list of Artist.Image structs.

  Prefers medium-sized images (300-800px). Falls back to first image or nil.
  """
  @spec pick_cover_url([Image.t()]) :: String.t() | nil
  def pick_cover_url([]), do: nil

  def pick_cover_url(images) do
    medium = Enum.find(images, fn img -> img.height >= 300 && img.height <= 800 end)

    case medium || List.first(images) do
      %Image{url: url} -> url
      _ -> nil
    end
  end

  @doc """
  Extracts the Tidal sharing URL from an externalLinks list.

  Returns the href of the first TIDAL_SHARING link, or nil.
  """
  @spec parse_tidal_url(list(map())) :: String.t() | nil
  def parse_tidal_url(links) do
    case Enum.find(links, fn l -> get_in(l, ["meta", "type"]) == "TIDAL_SHARING" end) do
      %{"href" => href} -> href
      _ -> nil
    end
  end

  @spec parse_component(String.t(), Regex.t()) :: non_neg_integer()
  defp parse_component(duration, regex) do
    case Regex.run(regex, duration) do
      [_, val] -> String.to_integer(val)
      _ -> 0
    end
  end
end
