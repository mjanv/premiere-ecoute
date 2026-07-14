defmodule PremiereEcouteWeb.Images.ImageProxyController do
  @moduledoc """
  Proxies remote cover images through the local server.

  On first request (cache miss), fetches the image from the remote URL,
  writes it to priv/static/images/proxy/, and serves it with long-lived
  cache headers. On subsequent requests (cache hit), serves from disk
  without touching the remote provider.
  """

  use PremiereEcouteWeb, :controller

  @cache_dir Application.app_dir(:premiere_ecoute, "priv/static/images/proxy")

  # SSRF guard — only fetch from known image CDNs, never arbitrary URLs.
  @allowed_hosts ~w(
    i.scdn.co
    mosaic.scdn.co
    cdn-images.dzcdn.net
    api.deezer.com
    resources.tidal.com
  )

  def show(conn, %{"url" => url}) do
    if allowed_url?(url) do
      cache_path = cache_path_for(url)

      case read_cached(cache_path) do
        {:ok, body, content_type} -> serve(conn, body, content_type)
        :miss -> fetch_and_cache(conn, url, cache_path)
      end
    else
      send_resp(conn, 400, "url not allowed")
    end
  end

  def show(conn, _params) do
    send_resp(conn, 400, "missing url param")
  end

  defp allowed_url?(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host} when is_binary(host) ->
        host in @allowed_hosts

      _ ->
        false
    end
  end

  defp read_cached(base_path) do
    Enum.find_value(~w(.jpg .png .webp .gif), :miss, fn ext ->
      path = base_path <> ext

      case File.read(path) do
        {:ok, body} -> {:ok, body, MIME.from_path(path)}
        {:error, _} -> nil
      end
    end)
  end

  defp fetch_and_cache(conn, url, base_path) do
    req_options = Application.get_env(:premiere_ecoute, __MODULE__, [])[:req_options] || []
    req = Req.new(req_options)

    case Req.get(req, url: url) do
      {:ok, %{status: 200, body: body, headers: headers}} ->
        content_type =
          headers |> Map.get("content-type", ["image/jpeg"]) |> List.first()

        bare_type = content_type |> String.split(";") |> List.first() |> String.trim()
        ext = ext_for(bare_type)
        final_path = base_path <> ext

        File.mkdir_p!(Path.dirname(final_path))
        File.write!(final_path, body)

        serve(conn, body, content_type)

      _ ->
        send_resp(conn, 502, "failed to fetch image")
    end
  end

  defp serve(conn, body, content_type) do
    conn
    |> put_resp_content_type(content_type)
    |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
    |> send_resp(200, body)
  end

  defp cache_path_for(url) do
    hash = :crypto.hash(:md5, url) |> Base.encode16(case: :lower)
    Path.join(cache_dir(), hash)
  end

  defp cache_dir do
    Application.get_env(:premiere_ecoute, __MODULE__, [])[:cache_dir] || @cache_dir
  end

  defp ext_for("image/jpeg"), do: ".jpg"
  defp ext_for("image/png"), do: ".png"
  defp ext_for("image/webp"), do: ".webp"
  defp ext_for("image/gif"), do: ".gif"
  defp ext_for(_), do: ".jpg"
end
