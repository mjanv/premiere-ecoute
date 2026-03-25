defmodule PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Summary do
  @moduledoc """
  Wikipedia REST API — page summary endpoint.

  Fetches the introduction extract and thumbnail for a page by title.
  Uses the en.wikipedia.org/api/rest_v1/page/summary/:title endpoint,
  which is separate from the MediaWiki action API.
  """

  @rest_base "https://en.wikipedia.org/api/rest_v1/page/summary"
  @user_agent "PremiereEcoute/1.0 (maxime.janvier@gmail.com)"

  @type summary :: %{
          title: String.t(),
          extract: String.t(),
          thumbnail_url: String.t() | nil,
          page_url: String.t() | nil
        }

  @doc """
  Fetches the summary for a Wikipedia page by its exact title.

  Returns `{:ok, summary}` on success, `{:error, :not_found}` when no page
  matches, or `{:error, reason}` for other failures.
  """
  @spec get(String.t()) :: {:ok, summary()} | {:error, term()}
  def get(title) when is_binary(title) do
    encoded = URI.encode(title)

    case Req.get("#{@rest_base}/#{encoded}", headers: [{"User-Agent", @user_agent}]) do
      {:ok, %{status: 200, body: body}} -> {:ok, parse(body)}
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse(body) do
    %{
      title: body["title"],
      extract: body["extract"],
      thumbnail_url: get_in(body, ["thumbnail", "source"]),
      page_url: get_in(body, ["content_urls", "desktop", "page"])
    }
  end
end
