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
end
