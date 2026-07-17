defmodule PremiereEcouteWeb.Plugs.ContentSecurityPolicyTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias PremiereEcouteWeb.Plugs.ContentSecurityPolicy

  setup do
    original = Application.get_env(:premiere_ecoute, :csp)
    on_exit(fn -> Application.put_env(:premiere_ecoute, :csp, original) end)
    :ok
  end

  defp policy(conn, header), do: conn |> get_resp_header(header) |> List.first()

  test "enforces the policy by default" do
    Application.delete_env(:premiere_ecoute, :csp)

    conn = ContentSecurityPolicy.call(conn(:get, "/"), [])

    assert get_resp_header(conn, "content-security-policy-report-only") == []
    policy = policy(conn, "content-security-policy")

    assert policy =~ "default-src 'self'"
    assert policy =~ "object-src 'none'"
    assert policy =~ "frame-ancestors 'self'"
    assert policy =~ "base-uri 'self'"
    assert policy =~ "form-action 'self'"
    # Origins the frontend actually needs
    assert policy =~ "https://unpkg.com"
    assert policy =~ "https://eu.i.posthog.com"
    assert policy =~ "https://www.youtube.com"
  end

  test "emits a report-only header when csp: :report_only" do
    Application.put_env(:premiere_ecoute, :csp, :report_only)

    conn = ContentSecurityPolicy.call(conn(:get, "/"), [])

    assert get_resp_header(conn, "content-security-policy") == []
    assert policy(conn, "content-security-policy-report-only") =~ "default-src 'self'"
  end
end
