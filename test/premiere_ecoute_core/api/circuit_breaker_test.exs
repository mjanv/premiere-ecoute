defmodule PremiereEcouteCore.Api.CircuitBreakerTest do
  use ExUnit.Case, async: true

  alias PremiereEcouteCore.Api.CircuitBreaker

  describe "retry_after_seconds/1" do
    test "parses the delay-seconds form" do
      assert CircuitBreaker.retry_after_seconds("120") == 120
    end

    test "parses the RFC-legal HTTP-date form" do
      retry_at = DateTime.utc_now() |> DateTime.add(90, :second) |> DateTime.truncate(:second)
      header = Calendar.strftime(retry_at, "%a, %d %b %Y %H:%M:%S GMT")

      assert_in_delta CircuitBreaker.retry_after_seconds(header), 90, 2
    end

    test "clamps an HTTP-date already in the past to zero instead of going negative" do
      retry_at = DateTime.utc_now() |> DateTime.add(-90, :second) |> DateTime.truncate(:second)
      header = Calendar.strftime(retry_at, "%a, %d %b %Y %H:%M:%S GMT")

      assert CircuitBreaker.retry_after_seconds(header) == 0
    end

    test "falls back to 60 seconds for an unparseable value" do
      assert CircuitBreaker.retry_after_seconds("not-a-valid-header") == 60
    end
  end

  describe "quota_exceeded?/1" do
    test "detects Spotify's QUOTA_EXCEEDED reason" do
      body = %{"error" => %{"status" => 429, "message" => "Too many requests", "reason" => "QUOTA_EXCEEDED"}}

      assert CircuitBreaker.quota_exceeded?(body)
    end

    test "does not flag a plain rate-limit 429 body" do
      refute CircuitBreaker.quota_exceeded?(%{"error" => %{"status" => 429, "message" => "Rate limit exceeded"}})
    end

    test "does not flag non-map bodies" do
      refute CircuitBreaker.quota_exceeded?("some html error page")
      refute CircuitBreaker.quota_exceeded?(nil)
    end
  end
end
