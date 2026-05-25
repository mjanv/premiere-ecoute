defmodule PremiereEcouteWeb.Images.ImageProxyControllerTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias PremiereEcouteWeb.Images.ImageProxyController

  setup {Req.Test, :verify_on_exit!}

  setup do
    cache_dir = Application.get_env(:premiere_ecoute, ImageProxyController)[:cache_dir]
    on_exit(fn -> File.rm_rf!(cache_dir) end)
    :ok
  end

  @image_url "https://i.scdn.co/image/abc123"
  @image_body <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10>>

  describe "GET /img" do
    test "cache miss: fetches from remote URL and returns image with cache headers", %{conn: conn} do
      Req.Test.stub(ImageProxyController, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "image/jpeg")
        |> Plug.Conn.send_resp(200, @image_body)
      end)

      conn = get(conn, ~p"/img?url=#{@image_url}")

      assert conn.status == 200
      assert conn.resp_body == @image_body
      assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
    end

    test "cache miss: strips content-type params before choosing file extension", %{conn: conn} do
      Req.Test.stub(ImageProxyController, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "image/webp; charset=utf-8")
        |> Plug.Conn.send_resp(200, @image_body)
      end)

      get(conn, ~p"/img?url=#{@image_url}")

      cache_dir = Application.get_env(:premiere_ecoute, ImageProxyController)[:cache_dir]
      cached_files = File.ls!(cache_dir)
      assert Enum.any?(cached_files, &String.ends_with?(&1, ".webp"))
    end

    test "cache hit: serves from disk without hitting remote URL", %{conn: conn} do
      Req.Test.stub(ImageProxyController, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "image/jpeg")
        |> Plug.Conn.send_resp(200, @image_body)
      end)

      # First request — populates cache
      get(conn, ~p"/img?url=#{@image_url}")

      # Second request — must NOT reach the stub
      Req.Test.stub(ImageProxyController, fn _conn ->
        raise "should not reach remote on cache hit"
      end)

      conn2 = get(conn, ~p"/img?url=#{@image_url}")

      assert conn2.status == 200
      assert conn2.resp_body == @image_body
    end

    test "upstream failure returns 502", %{conn: conn} do
      Req.Test.stub(ImageProxyController, fn conn ->
        Plug.Conn.send_resp(conn, 404, "not found")
      end)

      conn = get(conn, ~p"/img?url=#{@image_url}")

      assert conn.status == 502
    end

    test "disallowed host returns 400", %{conn: conn} do
      conn = get(conn, ~p"/img?url=https://evil.com/steal.jpg")

      assert conn.status == 400
    end

    test "http (non-https) url returns 400", %{conn: conn} do
      conn = get(conn, ~p"/img?url=http://i.scdn.co/image/abc123")

      assert conn.status == 400
    end

    test "missing url param returns 400", %{conn: conn} do
      conn = get(conn, ~p"/img")

      assert conn.status == 400
    end
  end
end
