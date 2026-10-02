defmodule PremiereEcouteWeb.ReturnTo do
  @moduledoc """
  Remembers which page a user came from, so a "back" link can bring them back to it with its filters.

  Origin pages link to a session with a `return_to` query param holding their own path and query. The session page
  validates it against a short allowlist of internal pages before using it, so the param can never redirect off-site.
  """

  @allowed [
    {"/sessions/retrospective", :history},
    {"/discography/albums", :album},
    {"/discography/artists", :artist},
    {"/discography/singles", :single},
    {"/home", :home},
    {"/users", :profile}
  ]

  @doc """
  Resolves a `return_to` param to a `{path, kind}` pair.

  Falls back to `default` (a history page path) when the param is missing or not an allowed internal page.
  """
  @spec resolve(term(), String.t()) :: {String.t(), atom()}
  def resolve(return_to, default) do
    case classify(return_to) do
      nil -> {default, :history}
      kind -> {return_to, kind}
    end
  end

  @doc """
  Builds the link to a session page, carrying `return_to` when it is a valid internal page.
  """
  @spec session_href(String.t(), String.t(), term()) :: String.t()
  def session_href(username, share_token, return_to) do
    path = "/sessions/#{username}/#{share_token}"

    case classify(return_to) do
      nil -> path
      _kind -> path <> "?" <> URI.encode_query(%{return_to: return_to})
    end
  end

  @doc """
  Returns the path and query of a URL, which is what origin pages pass as `return_to`.
  """
  @spec current_path(String.t()) :: String.t()
  def current_path(url) do
    %URI{path: path, query: query} = URI.parse(url)
    if query, do: "#{path}?#{query}", else: path
  end

  defp classify(return_to) when is_binary(return_to) do
    with %URI{scheme: nil, host: nil, path: "/" <> _ = path} <- URI.parse(return_to),
         false <- String.starts_with?(return_to, "//"),
         false <- String.contains?(return_to, ["\\", "..", "\r", "\n"]),
         {_prefix, kind} <- Enum.find(@allowed, fn {prefix, _kind} -> allowed?(path, prefix) end),
         false <- settings?(path) do
      kind
    else
      _ -> nil
    end
  end

  defp classify(_return_to), do: nil

  defp allowed?(path, prefix), do: path == prefix or String.starts_with?(path, prefix <> "/")

  defp settings?(path), do: String.starts_with?(path, ["/users/settings", "/users/account", "/users/log-in"])
end
