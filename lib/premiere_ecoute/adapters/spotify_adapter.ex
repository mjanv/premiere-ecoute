defmodule PremiereEcoute.Adapters.SpotifyAdapter do
  @moduledoc """
  Spotify API adapter that implements the MusicMetadataPort.
  Converts all Spotify API responses to proper Elixir structs.
  """

  @behaviour PremiereEcoute.Core.Ports.MusicMetadataPort

  alias PremiereEcoute.Core.Entities.{Album, Track}
  alias PremiereEcoute.Core.Ports.MusicMetadataPort

  require Logger

  @spotify_api_base "https://api.spotify.com/v1"

  @impl MusicMetadataPort
  def search_albums(query) when is_binary(query) do
    case get_access_token() do
      {:ok, token} ->
        search_url = "#{@spotify_api_base}/search?q=#{URI.encode(query)}&type=album&limit=20"

        case Req.get(search_url, headers: [{"Authorization", "Bearer #{token}"}]) do
          {:ok, %{status: 200, body: body}} ->
            albums = parse_search_results(body)
            {:ok, albums}

          {:ok, %{status: status, body: body}} ->
            Logger.error("Spotify search failed: #{status} - #{inspect(body)}")
            {:error, "Spotify API error: #{status}"}

          {:error, reason} ->
            Logger.error("Spotify request failed: #{inspect(reason)}")
            {:error, "Network error: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl MusicMetadataPort
  def get_album_with_tracks(album_id) when is_binary(album_id) do
    case get_access_token() do
      {:ok, token} ->
        album_url = "#{@spotify_api_base}/albums/#{album_id}"

        case Req.get(album_url, headers: [{"Authorization", "Bearer #{token}"}]) do
          {:ok, %{status: 200, body: body}} ->
            album = parse_album_with_tracks(body)
            {:ok, album}

          {:ok, %{status: status, body: body}} ->
            Logger.error("Spotify album fetch failed: #{status} - #{inspect(body)}")
            {:error, "Spotify API error: #{status}"}

          {:error, reason} ->
            Logger.error("Spotify request failed: #{inspect(reason)}")
            {:error, "Network error: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl MusicMetadataPort
  def get_track_details(track_id) when is_binary(track_id) do
    case get_access_token() do
      {:ok, token} ->
        track_url = "#{@spotify_api_base}/tracks/#{track_id}"

        case Req.get(track_url, headers: [{"Authorization", "Bearer #{token}"}]) do
          {:ok, %{status: 200, body: body}} ->
            track = parse_track(body)
            {:ok, track}

          {:ok, %{status: status, body: body}} ->
            Logger.error("Spotify track fetch failed: #{status} - #{inspect(body)}")
            {:error, "Spotify API error: #{status}"}

          {:error, reason} ->
            Logger.error("Spotify request failed: #{inspect(reason)}")
            {:error, "Network error: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions for API interaction and data conversion

  defp get_access_token do
    client_id = Application.get_env(:premiere_ecoute, :spotify_client_id)
    client_secret = Application.get_env(:premiere_ecoute, :spotify_client_secret)

    if client_id && client_secret do
      auth_string = Base.encode64("#{client_id}:#{client_secret}")

      case Req.post("https://accounts.spotify.com/api/token",
             headers: [
               {"Authorization", "Basic #{auth_string}"},
               {"Content-Type", "application/x-www-form-urlencoded"}
             ],
             body: "grant_type=client_credentials"
           ) do
        {:ok, %{status: 200, body: %{"access_token" => token}}} ->
          {:ok, token}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Spotify auth failed: #{status} - #{inspect(body)}")
          {:error, "Spotify authentication failed"}

        {:error, reason} ->
          Logger.error("Spotify auth request failed: #{inspect(reason)}")
          {:error, "Network error during authentication"}
      end
    else
      {:error, "Spotify credentials not configured"}
    end
  end

  defp parse_search_results(%{"albums" => %{"items" => items}}) do
    Enum.map(items, fn item ->
      %{
        id: item["id"],
        name: item["name"],
        artist: get_primary_artist(item["artists"]),
        release_date: parse_release_date(item["release_date"]),
        cover_url: get_album_cover_url(item["images"]),
        total_tracks: item["total_tracks"] || 0
      }
    end)
  end

  defp parse_search_results(_), do: []

  defp parse_album_with_tracks(album_data) do
    tracks = parse_tracks(album_data["tracks"]["items"] || [], album_data["id"])

    %Album{
      spotify_id: album_data["id"],
      name: album_data["name"],
      artist: get_primary_artist(album_data["artists"]),
      release_date: parse_release_date(album_data["release_date"]),
      cover_url: get_album_cover_url(album_data["images"]),
      total_tracks: album_data["total_tracks"] || 0,
      tracks: tracks,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp parse_tracks(track_items, album_id) do
    Enum.map(track_items, fn track ->
      %Track{
        spotify_id: track["id"],
        album_id: album_id,
        name: track["name"],
        track_number: track["track_number"] || 0,
        duration_ms: track["duration_ms"] || 0,
        preview_url: track["preview_url"],
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    end)
  end

  defp parse_track(track_data) do
    %Track{
      spotify_id: track_data["id"],
      album_id: track_data["album"]["id"],
      name: track_data["name"],
      track_number: track_data["track_number"] || 0,
      duration_ms: track_data["duration_ms"] || 0,
      preview_url: track_data["preview_url"],
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp get_primary_artist(artists) when is_list(artists) do
    case List.first(artists) do
      %{"name" => name} -> name
      _ -> "Unknown Artist"
    end
  end

  defp get_primary_artist(_), do: "Unknown Artist"

  defp parse_release_date(nil), do: nil
  defp parse_release_date(""), do: nil

  defp parse_release_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        date

      {:error, _} ->
        # Try parsing year-only format
        case Integer.parse(date_string) do
          {year, _} when year > 1900 -> Date.new(year, 1, 1) |> elem(1)
          _ -> nil
        end
    end
  end

  defp get_album_cover_url(images) when is_list(images) do
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

  defp get_album_cover_url(_), do: nil
end
