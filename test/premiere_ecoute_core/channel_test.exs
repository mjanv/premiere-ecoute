defmodule PremiereEcouteCore.ChannelTest do
  use ExUnit.Case, async: true

  alias PremiereEcouteCore.ChannelRegistry
  import PremiereEcouteCore.Channel

  describe "sigil" do
    test "works" do
      id = 5

      assert ~h[ok:#{id}]part == "ok:5"

      assert PremiereEcoute.Prout.__channels__() == ["user:_", "artist:_"]
      assert ChannelRegistry.all() == ["user:_", "artist:_"]
    end
  end
end
