defmodule PremiereEcouteWeb.Podcasts.CoverController do
  @moduledoc """
  Streams a show's cover image through the app so the object store stays private (no public bucket).

  Addressed by show id so the URL is stable across slug changes and works for drafts (studio
  previews) as well as published feeds. Cover art is not sensitive, so no auth is required.
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Podcasts
  alias PremiereEcoute.Podcasts.Show
  alias PremiereEcoute.Podcasts.Storage

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    case Podcasts.get_show(id) do
      %Show{cover_key: key} when is_binary(key) -> Storage.send_object(conn, key, content_type(key))
      _ -> send_resp(conn, 404, "Not found")
    end
  end

  defp content_type(key) do
    case key |> Path.extname() |> String.downcase() do
      ".png" -> "image/png"
      ext when ext in [".jpg", ".jpeg"] -> "image/jpeg"
      _ -> "application/octet-stream"
    end
  end
end
