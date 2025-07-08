defmodule PremiereEcouteWeb.MetricsTest do
  use PremiereEcouteWeb.ConnCase

  test "GET /metrics", %{conn: conn} do
    conn = get(conn, "/metrics")
    response_body = response(conn, 200)

    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]

    assert String.contains?(response_body, "# HELP")
    assert String.contains?(response_body, "# TYPE")
  end
end
