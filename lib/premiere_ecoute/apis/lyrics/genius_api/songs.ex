defmodule PremiereEcoute.Apis.Lyrics.GeniusApi.Songs do
  @moduledoc """
  Genius songs API.

  Fetches detailed song information by Genius song ID.
  """

  alias PremiereEcoute.Apis.Lyrics.GeniusApi

  @doc """
  Fetches details for a song by Genius ID.

  Returns a map with id, title, full_title, artist, url, release_date,
  thumbnail_url, pageviews, lyrics metadata, and primary_artist details.
  """
  @spec get_song(integer()) :: {:ok, map()} | {:error, term()}
  def get_song(id) when is_integer(id) do
    GeniusApi.api()
    |> GeniusApi.get(url: "/songs/#{id}")
    |> GeniusApi.handle(200, fn %{"response" => %{"song" => song}} ->
      artist = song["primary_artist"]

      %{
        id: song["id"],
        title: song["title"],
        full_title: song["full_title"],
        artist: song["artist_names"],
        url: song["url"],
        path: song["path"],
        release_date: song["release_date"],
        language: song["language"],
        thumbnail_url: song["song_art_image_thumbnail_url"],
        image_url: song["song_art_image_url"],
        pageviews: get_in(song, ["stats", "pageviews"]),
        annotation_count: song["annotation_count"],
        pyongs_count: song["pyongs_count"],
        lyrics_state: song["lyrics_state"],
        lyrics_owner_id: song["lyrics_owner_id"],
        lyrics_marked_complete_by: song["lyrics_marked_complete_by"],
        lyrics_marked_staff_approved_by: song["lyrics_marked_staff_approved_by"],
        embed_content: song["embed_content"],
        translations:
          Enum.map(song["translation_songs"] || [], fn t ->
            %{id: t["id"], language: t["language"], title: t["title"], url: t["url"]}
          end),
        primary_artist: %{
          id: artist["id"],
          name: artist["name"],
          url: artist["url"],
          image_url: artist["image_url"]
        }
      }
    end)
  end
end
