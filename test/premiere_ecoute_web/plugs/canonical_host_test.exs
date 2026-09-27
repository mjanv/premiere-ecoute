defmodule PremiereEcouteWeb.Plugs.CanonicalHostTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias PremiereEcouteWeb.Plugs.CanonicalHost

  describe "call/2" do
    test "redirects a request on another host to the canonical host, keeping path and query" do
      conn =
        build_conn(:get, "http://127.0.0.1:4000/auth/spotify/callback?code=abc&state=xyz")
        |> CanonicalHost.call(host: "localhost")

      assert conn.halted
      assert redirected_to(conn, 302) == "http://localhost:4000/auth/spotify/callback?code=abc&state=xyz"
    end

    test "passes through a request on the canonical host" do
      conn =
        build_conn(:get, "http://localhost:4000/auth/spotify/callback?code=abc")
        |> CanonicalHost.call(host: "localhost")

      refute conn.halted
    end

    test "passes through when no canonical host is configured" do
      conn =
        build_conn(:get, "http://127.0.0.1:4000/")
        |> CanonicalHost.call(host: nil)

      refute conn.halted
    end
  end
end
