defmodule PremiereEcoute.Apis.Streaming.TwitchApi.Videos do
  @moduledoc """
  Twitch videos API.

  Retrieves videos of a broadcaster or a single video by identifier.
  """

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.Streaming.TwitchApi
  alias PremiereEcoute.Twitch.Video

  @page_size 100

  @doc """
  Returns a video by identifier.
  """
  @spec get_video(Scope.t(), Video.id()) :: {:ok, Video.t()} | {:error, term()}
  def get_video(%Scope{} = scope, video_id) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.get(url: "/videos", params: %{id: video_id})
    |> TwitchApi.handle(200, fn %{"data" => [video | _]} -> Video.parse(video) end)
  end

  @doc """
  Returns the videos of the broadcaster.

  Options:

  - `:type` - `:all`, `:archive`, `:highlight` or `:upload`
  - `:period` - `:all`, `:day`, `:week` or `:month`
  - `:sort` - `:time`, `:trending` or `:views`
  - `:limit` - maximum number of videos returned (default: all)
  """
  @spec get_videos(Scope.t(),
          type: :all | Video.type(),
          period: :all | :day | :week | :month,
          sort: :time | :trending | :views,
          limit: pos_integer()
        ) ::
          {:ok, [Video.t()]} | {:error, term()}
  def get_videos(%Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope, opts \\ []) do
    filters = opts |> Keyword.take([:type, :period, :sort]) |> Map.new()
    params = Map.put(filters, :user_id, broadcaster_id)

    fetch_videos(scope, params, Keyword.get(opts, :limit, :infinity), [])
  end

  defp fetch_videos(scope, params, limit, acc) do
    page_size = limit |> remaining(acc) |> min(@page_size)

    result =
      scope
      |> TwitchApi.api()
      |> TwitchApi.get(url: "/videos", params: Map.put(params, :first, page_size))
      |> TwitchApi.handle(200, fn %{"data" => videos} = body ->
        {Enum.map(videos, &Video.parse/1), get_in(body, ["pagination", "cursor"])}
      end)

    case result do
      {:ok, {videos, cursor}} ->
        acc = acc ++ videos

        if cursor && remaining(limit, acc) > 0 do
          fetch_videos(scope, Map.put(params, :after, cursor), limit, acc)
        else
          {:ok, acc}
        end

      {:error, _} = error ->
        error
    end
  end

  defp remaining(:infinity, _acc), do: @page_size
  defp remaining(limit, acc), do: limit - length(acc)
end
