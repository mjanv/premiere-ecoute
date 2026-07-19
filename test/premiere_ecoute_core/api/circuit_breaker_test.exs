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
end
