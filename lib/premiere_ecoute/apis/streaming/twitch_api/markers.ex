defmodule PremiereEcoute.Apis.Streaming.TwitchApi.Markers do
  @moduledoc """
  Twitch stream markers API.

  Creates markers in the current live stream and retrieves markers of a broadcaster's latest video or of a given video.
  """

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.Streaming.TwitchApi
  alias PremiereEcoute.Twitch.Marker

  @doc """
  Creates a marker in the broadcaster's live stream.

  Requires the `channel:manage:broadcast` scope. The stream must be live and have VODs enabled. Description is limited to 140 characters.
  """
  @spec create_marker(Scope.t(), String.t() | nil) :: {:ok, Marker.t()} | {:error, term()}
  def create_marker(%Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope, description \\ nil) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.post(
      url: "/streams/markers",
      json: %{user_id: broadcaster_id, description: description} |> Map.reject(fn {_, v} -> is_nil(v) end)
    )
    |> TwitchApi.handle(200, fn %{"data" => [marker | _]} -> Marker.parse(marker) end)
  end

  @doc """
  Returns the markers of a video.

  Targets the broadcaster's latest video by default, or the video given with the `:video_id` option.
  """
  @spec get_markers(Scope.t(), video_id: String.t()) :: {:ok, [Marker.t()]} | {:error, term()}
  def get_markers(%Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope, opts \\ []) do
    fetch_markers(scope, target(broadcaster_id, opts), [])
  end

  defp fetch_markers(scope, params, acc) do
    result =
      scope
      |> TwitchApi.api()
      |> TwitchApi.get(url: "/streams/markers", params: params)
      |> TwitchApi.handle(200, fn body -> {parse_markers(body), get_in(body, ["pagination", "cursor"])} end)

    case result do
      {:ok, {markers, nil}} -> {:ok, acc ++ markers}
      {:ok, {markers, cursor}} -> fetch_markers(scope, Map.put(params, :after, cursor), acc ++ markers)
      {:error, _} = error -> error
    end
  end

  defp target(broadcaster_id, opts) do
    case Keyword.fetch(opts, :video_id) do
      {:ok, video_id} -> %{video_id: video_id}
      :error -> %{user_id: broadcaster_id}
    end
  end

  defp parse_markers(%{"data" => data}) do
    for %{"videos" => videos} <- data,
        %{"video_id" => video_id, "markers" => markers} <- videos,
        marker <- markers do
      marker |> Map.put("video_id", video_id) |> Marker.parse()
    end
  end
end
