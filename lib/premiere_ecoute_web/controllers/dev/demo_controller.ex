defmodule PremiereEcouteWeb.Dev.DemoController do
  @moduledoc """
  Serves standalone demo pages in development.

  Each `priv/demos/<name>.html` file is a self-contained page available at `/dev/demos/<name>`.
  Add a file to add a demo. The routes only exist when `dev_routes` is enabled.
  """

  use PremiereEcouteWeb, :controller

  @doc """
  Lists the available demos.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    links =
      Enum.map_join(demos(), "\n", fn name ->
        ~s(<li><a href="/dev/demos/#{name}">#{name}</a></li>)
      end)

    html(conn, """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Demos</title>
    <style>
      body { margin: 0; padding: 48px 24px; background: #000; color: #fff; font: 600 18px/1.6 system-ui, sans-serif; }
      h1 { margin: 0 0 16px; font-size: 14px; letter-spacing: 0.14em; text-transform: uppercase; color: #ffffff80; }
      ul { margin: 0; padding: 0; list-style: none; }
      a { color: inherit; }
    </style>
    </head>
    <body>
    <h1>Demos</h1>
    <ul>
    #{links}
    </ul>
    </body>
    </html>
    """)
  end

  @doc """
  Serves one demo page, or 404 when no demo has that name.
  """
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"name" => name}) do
    if name in demos() do
      html(conn, File.read!(Path.join(directory(), name <> ".html")))
    else
      send_resp(conn, :not_found, "Not found")
    end
  end

  defp demos do
    directory()
    |> Path.join("*.html")
    |> Path.wildcard()
    |> Enum.map(&Path.basename(&1, ".html"))
    |> Enum.sort()
  end

  defp directory, do: Application.app_dir(:premiere_ecoute, "priv/demos")
end
