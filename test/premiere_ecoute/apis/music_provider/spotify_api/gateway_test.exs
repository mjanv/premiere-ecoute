defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.GatewayTest do
  use ExUnit.Case, async: false

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Gateway

  defmodule Raiser do
    def boom(%{spotify: %{access_token: _}}), do: :ok
  end

  describe "call/3" do
    test "returns an error instead of crashing when the target function raises" do
      assert {:error, %FunctionClauseError{}} = Gateway.call(Raiser, :boom, [:whatever])
    end

    test "keeps serving other callers after a call raises" do
      pid_before = Process.whereis(Gateway)

      Gateway.call(Raiser, :boom, [:whatever])

      assert Process.whereis(Gateway) == pid_before
      assert Gateway.call(Kernel, :is_atom, [:ok]) == true
    end
  end
end
