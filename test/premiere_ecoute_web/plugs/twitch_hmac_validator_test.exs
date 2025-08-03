defmodule PremiereEcouteWeb.Plugs.TwitchHmacValidatorTest do
  use PremiereEcouteWeb.ConnCase

  alias PremiereEcouteWeb.Plugs.TwitchHmacValidator

  describe "hmac/1" do
    @secret "b29f90a1d6e75024b550d740ef56e2fc7610a0b7e6a4108f64c79933b5cfbe01"
    @body "{}"

    test "assert that a received body is signed with the right secret" do
      headers = [
        {"twitch-eventsub-message-id", "d3b0a4c4-6c67-4b1b-9db1-5e307f6ef9f9"},
        {"twitch-eventsub-message-timestamp", "2025-08-02T15:12:34.000Z"},
        {"twitch-eventsub-message-signature", "sha256=41c284568e5105bc90725e2be60314f79e8c13eff34095e49915a53f7f0b8bf4"}
      ]

      assert TwitchHmacValidator.hmac(headers, @secret, @body) == true
    end

    test "refuses that a received body is signed with the wrong secret" do
      headers = [
        {"twitch-eventsub-message-id", "d3b0a4c4-6c67-4b1b-9db1-5e307f6ef9f9"},
        {"twitch-eventsub-message-timestamp", "2025-08-02T15:12:34.000Z"},
        {"twitch-eventsub-message-signature", "sha256=5f2d5e90b2a3d48e1f8a775e6dd4e769ee5796e48c91c7f4f3d7bb4f07dfb23f"}
      ]

      assert TwitchHmacValidator.hmac(headers, @secret, @body) == false
    end

    test "refutes that a received body is signed with the wrong id" do
      headers = [
        {"twitch-eventsub-message-id", UUID.uuid4()},
        {"twitch-eventsub-message-timestamp", "2025-08-02T15:12:34.000Z"},
        {"twitch-eventsub-message-signature", "sha256=41c284568e5105bc90725e2be60314f79e8c13eff34095e49915a53f7f0b8bf4"}
      ]

      assert TwitchHmacValidator.hmac(headers, @secret, @body) == false
    end

    test "refutes that a received body is signed with the wrong timestamp" do
      headers = [
        {"twitch-eventsub-message-id", "d3b0a4c4-6c67-4b1b-9db1-5e307f6ef9f9"},
        {"twitch-eventsub-message-timestamp", "2025-08-02T15:12:35.000Z"},
        {"twitch-eventsub-message-signature", "sha256=41c284568e5105bc90725e2be60314f79e8c13eff34095e49915a53f7f0b8bf4"}
      ]

      assert TwitchHmacValidator.hmac(headers, @secret, @body) == false
    end

    test "refuses that a received body is signed without secret" do
      headers = [
        {"twitch-eventsub-message-id", "d3b0a4c4-6c67-4b1b-9db1-5e307f6ef9f9"},
        {"twitch-eventsub-message-timestamp", "2025-08-02T15:12:34.000Z"}
      ]

      assert TwitchHmacValidator.hmac(headers, @secret, @body) == false
    end

    test "refuses that a received body is signed without headers" do
      headers = []

      assert TwitchHmacValidator.hmac(headers, @secret, @body) == false
    end
  end
end
