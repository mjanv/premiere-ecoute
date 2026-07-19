defmodule PremiereEcouteWeb.Plugs.LoginRateLimitTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias PremiereEcouteWeb.Plugs.LoginRateLimit

  setup do
    start_supervised(PremiereEcoute.Apis.RateLimit.RateLimiter)
    :ok
  end

  defp request(email, ip \\ {10, 0, 0, :rand.uniform(254)}) do
    %{conn(:post, "/users/log-in", %{}) | remote_ip: ip}
    |> Map.put(:body_params, %{"user" => %{"email" => email, "password" => "whatever"}})
  end

  test "allows attempts under the limit, then 429s with Retry-After for a given email" do
    email = "victim-#{System.unique_integer([:positive])}@example.com"

    for _ <- 1..10 do
      refute LoginRateLimit.call(request(email), []).halted
    end

    denied = LoginRateLimit.call(request(email), [])

    assert denied.status == 429
    assert denied.halted
    assert get_resp_header(denied, "retry-after") == ["60"]
  end

  test "rate limits are independent per email" do
    email_a = "a-#{System.unique_integer([:positive])}@example.com"
    email_b = "b-#{System.unique_integer([:positive])}@example.com"

    for _ <- 1..10, do: LoginRateLimit.call(request(email_a), [])

    assert LoginRateLimit.call(request(email_a), []).status == 429
    refute LoginRateLimit.call(request(email_b), []).halted
  end

  test "falls back to client IP when no email is present (e.g. magic-link submission)" do
    ip = {10, 0, 1, :rand.uniform(254)}
    conn_without_email = %{conn(:post, "/users/log-in", %{}) | remote_ip: ip} |> Map.put(:body_params, %{})

    for _ <- 1..10 do
      refute LoginRateLimit.call(conn_without_email, []).halted
    end

    assert LoginRateLimit.call(conn_without_email, []).status == 429
  end
end
