defmodule PremiereEcoute.Podcasts.Storage.LocalTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias PremiereEcoute.Podcasts.Storage.Local

  setup do
    key = "podcasts/test/#{System.unique_integer([:positive])}.bin"
    :ok = Local.put(key, "0123456789")
    on_exit(fn -> Local.delete(key) end)
    %{key: key}
  end

  describe "send_object/3 (range serving)" do
    test "serves the full object with 200 and advertises ranges", %{key: key} do
      conn = conn(:get, "/") |> Local.send_object(key, "audio/mpeg")

      assert conn.status == 200
      assert conn.resp_body == "0123456789"
      assert get_resp_header(conn, "accept-ranges") == ["bytes"]
      assert get_resp_header(conn, "content-type") == ["audio/mpeg"]
    end

    test "serves a byte range with 206 and content-range", %{key: key} do
      conn =
        conn(:get, "/")
        |> put_req_header("range", "bytes=2-5")
        |> Local.send_object(key, "audio/mpeg")

      assert conn.status == 206
      assert conn.resp_body == "2345"
      assert get_resp_header(conn, "content-range") == ["bytes 2-5/10"]
    end

    test "serves an open-ended range to the end of the file", %{key: key} do
      conn =
        conn(:get, "/")
        |> put_req_header("range", "bytes=7-")
        |> Local.send_object(key, "audio/mpeg")

      assert conn.status == 206
      assert conn.resp_body == "789"
      assert get_resp_header(conn, "content-range") == ["bytes 7-9/10"]
    end

    test "returns 416 for an unsatisfiable range", %{key: key} do
      conn =
        conn(:get, "/")
        |> put_req_header("range", "bytes=100-200")
        |> Local.send_object(key, "audio/mpeg")

      assert conn.status == 416
    end

    test "returns 404 for a missing object" do
      conn = conn(:get, "/") |> Local.send_object("podcasts/test/missing.bin", "audio/mpeg")
      assert conn.status == 404
    end
  end
end
