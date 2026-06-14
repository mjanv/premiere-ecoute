defmodule PremiereEcouteWeb.Podcasts.CoverControllerTest do
  use PremiereEcouteWeb.ConnCase, async: false

  alias PremiereEcoute.Podcasts.Storage

  defmodule CoverStub do
    @behaviour PremiereEcoute.Podcasts.Storage

    import Plug.Conn

    @impl true
    def fetch(_key), do: {:error, :not_supported}
    @impl true
    def put(_key, _bytes), do: :ok
    @impl true
    def delete(_key), do: :ok

    @impl true
    def send_object(conn, key, content_type) do
      conn |> put_resp_header("content-type", content_type) |> send_resp(200, "IMG:" <> key)
    end
  end

  setup do
    Application.put_env(:premiere_ecoute, Storage, adapter: CoverStub)
    on_exit(fn -> Application.delete_env(:premiere_ecoute, Storage) end)
    %{user: user_fixture()}
  end

  test "streams the cover through the app with the right content type", %{conn: conn, user: user} do
    key = "podcasts/#{System.unique_integer([:positive])}/cover.png"
    show = show_fixture(user, %{cover_key: key})

    conn = get(conn, ~p"/podcasts/shows/#{show.id}/cover")

    assert response(conn, 200) == "IMG:#{key}"
    assert get_resp_header(conn, "content-type") == ["image/png"]
  end

  test "returns 404 when the show has no cover", %{conn: conn, user: user} do
    show = show_fixture(user, %{cover_key: nil})
    conn = get(conn, ~p"/podcasts/shows/#{show.id}/cover")
    assert response(conn, 404)
  end

  test "returns 404 for an unknown show", %{conn: conn} do
    conn = get(conn, ~p"/podcasts/shows/9999999/cover")
    assert response(conn, 404)
  end
end
