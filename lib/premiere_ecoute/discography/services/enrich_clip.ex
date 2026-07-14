defmodule PremiereEcoute.Discography.Services.EnrichClip do
  @moduledoc """
  Resolves a YouTube video into a Single for use as a listening session clip.

  Fetches the video's metadata, then cross-searches Spotify to find the real track
  it corresponds to (real artist, canonical name, cover art). A clip can only be
  used if it resolves to a genuine Spotify single — there is no fallback to
  unverified YouTube-only metadata, since a Single must be backed by a real Artist.
  """

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Single

  @match_threshold 0.75
  @noise_pattern ~r/\s*[\(\[][^\)\]]*(official|video|audio|lyric|mv|hd|4k)[^\)\]]*[\)\]]/i

  @doc """
  Resolves a YouTube video ID into a persisted Single and its YouTube thumbnail URL.

  Cross-searches Spotify using the cleaned video title; if a candidate's artist
  matches the video's channel closely enough, that Spotify single is used (and
  tagged with the YouTube video ID too). Returns `{:error, :no_match}` when no
  confident Spotify match is found — the clip cannot be prepared in that case.
  """
  @spec resolve_single(String.t()) :: {:ok, Single.t(), String.t() | nil} | {:error, term()}
  def resolve_single(youtube_video_id) when is_binary(youtube_video_id) do
    with {:ok, video} <- Apis.youtube().get_video(youtube_video_id),
         {:ok, %Single{} = single} <- find_spotify_match(video),
         {:ok, single} <- attach_youtube_id(single, youtube_video_id) do
      {:ok, single, video.thumbnail_url}
    else
      :error -> {:error, :no_match}
      error -> error
    end
  end

  defp find_spotify_match(video) do
    query = clean_title(video.title)

    case Apis.spotify().search_singles(query) do
      {:ok, candidates} when candidates != [] ->
        candidates
        |> Enum.map(fn candidate -> {match_score(candidate, video), candidate} end)
        |> Enum.filter(fn {score, _candidate} -> score > @match_threshold end)
        |> Enum.sort_by(fn {score, _candidate} -> score end, :desc)
        |> case do
          [{_score, best} | _] -> {:ok, best}
          [] -> :error
        end

      _ ->
        :error
    end
  end

  defp match_score(%Single{artists: artists}, video) do
    channel = String.downcase(video.channel_title || "")

    artists
    |> Enum.map(&String.jaro_distance(channel, String.downcase(&1.name || "")))
    |> Enum.max(fn -> 0.0 end)
  end

  defp attach_youtube_id(%Single{} = single, youtube_video_id) do
    with {:ok, persisted} <- Single.create_if_not_exists(single) do
      if Map.get(persisted.provider_ids, :youtube) == youtube_video_id do
        {:ok, persisted}
      else
        Single.update(persisted, %{provider_ids: Map.put(persisted.provider_ids, :youtube, youtube_video_id)})
      end
    end
  end

  defp clean_title(title) do
    title
    |> String.replace(@noise_pattern, "")
    |> String.trim()
  end
end
