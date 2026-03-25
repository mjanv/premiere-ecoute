defmodule PremiereEcoute.Apis.MusicMetadata.WikipediaApi.PageSummary do
  @moduledoc """
  Wikipedia REST API — page summary endpoint.

  Fetches the introduction extract and thumbnail for a page by title.
  Uses the en.wikipedia.org/api/rest_v1/page/summary/:title endpoint,
  which is separate from the MediaWiki action API.
  """

  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Page
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Summary

  @base_url "https://en.wikipedia.org/api/rest_v1/page/summary"
  @user_agent Application.compile_env(:premiere_ecoute, :user_agent, "")

  @doc """
  Fetches the summary for a Wikipedia page by its exact title.

  Returns `{:ok, summary}` on success, `{:error, :not_found}` when no page
  matches, or `{:error, reason}` for other failures.
  """
  @spec summary(Page.t()) :: {:ok, Summary.t()} | {:error, term()}
  def summary(%Page{title: title}) do
    case Req.get("#{@base_url}/#{URI.encode(title)}", headers: [{"User-Agent", @user_agent}]) do
      {:ok, %{status: 200, body: body}} -> {:ok, parse(body)}
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse(body) do
    %Summary{
      title: body["title"],
      extract: body["extract"],
      thumbnail_url: get_in(body, ["thumbnail", "source"]),
      page_url: get_in(body, ["content_urls", "desktop", "page"])
    }
  end
end
