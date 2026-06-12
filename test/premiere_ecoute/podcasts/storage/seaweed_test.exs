defmodule PremiereEcoute.Podcasts.Storage.SeaweedTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Podcasts.Storage.Seaweed

  setup do
    Application.put_env(:premiere_ecoute, Seaweed,
      filer_url: "http://filer.test:8888/",
      req_options: [plug: {Req.Test, Seaweed}]
    )

    on_exit(fn -> Application.delete_env(:premiere_ecoute, Seaweed) end)
    :ok
  end

  describe "put/2" do
    test "PUTs the raw body to the Filer at the key path and returns :ok" do
      Req.Test.stub(Seaweed, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/podcasts/1/episodes/g.mp3"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body == "AUDIOBYTES"
        Plug.Conn.send_resp(conn, 201, "")
      end)

      assert :ok = Seaweed.put("podcasts/1/episodes/g.mp3", "AUDIOBYTES")
    end

    test "surfaces an unexpected status" do
      Req.Test.stub(Seaweed, fn conn -> Plug.Conn.send_resp(conn, 500, "") end)
      assert {:error, {:unexpected_status, 500}} = Seaweed.put("k", "v")
    end
  end

  describe "fetch/1" do
    test "returns the body on 200" do
      Req.Test.stub(Seaweed, fn conn ->
        assert conn.method == "GET"
        Plug.Conn.send_resp(conn, 200, "BYTES")
      end)

      assert {:ok, "BYTES"} = Seaweed.fetch("podcasts/1/episodes/g.mp3")
    end

    test "maps 404 to :not_found" do
      Req.Test.stub(Seaweed, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)
      assert {:error, :not_found} = Seaweed.fetch("missing")
    end
  end

  describe "delete/1" do
    test "returns :ok on 204" do
      Req.Test.stub(Seaweed, fn conn ->
        assert conn.method == "DELETE"
        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert :ok = Seaweed.delete("podcasts/1/episodes/g.mp3")
    end

    test "treats a missing object (404) as already deleted" do
      Req.Test.stub(Seaweed, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)
      assert :ok = Seaweed.delete("missing")
    end
  end

  describe "send_object/3 (range proxy)" do
    test "streams a full object with 200 and advertises ranges" do
      Req.Test.stub(Seaweed, fn conn ->
        assert conn.method == "GET"
        Plug.Conn.send_resp(conn, 200, "BYTES")
      end)

      conn = Plug.Test.conn(:get, "/") |> Seaweed.send_object("k", "audio/mpeg")

      assert conn.status == 200
      assert conn.resp_body == "BYTES"
      assert Plug.Conn.get_resp_header(conn, "accept-ranges") == ["bytes"]
      assert Plug.Conn.get_resp_header(conn, "content-type") == ["audio/mpeg"]
    end

    test "forwards the Range header and mirrors the Filer's 206 + content-range" do
      Req.Test.stub(Seaweed, fn conn ->
        assert Plug.Conn.get_req_header(conn, "range") == ["bytes=0-3"]

        conn
        |> Plug.Conn.put_resp_header("content-range", "bytes 0-3/10")
        |> Plug.Conn.send_resp(206, "BYTE")
      end)

      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.put_req_header("range", "bytes=0-3")
        |> Seaweed.send_object("k", "audio/mpeg")

      assert conn.status == 206
      assert conn.resp_body == "BYTE"
      assert Plug.Conn.get_resp_header(conn, "content-range") == ["bytes 0-3/10"]
    end

    test "returns 404 when the object is missing" do
      Req.Test.stub(Seaweed, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)
      conn = Plug.Test.conn(:get, "/") |> Seaweed.send_object("missing", "audio/mpeg")
      assert conn.status == 404
    end
  end
end
