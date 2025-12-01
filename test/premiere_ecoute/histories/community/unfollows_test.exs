defmodule PremiereEcoute.Twitch.History.Community.UnfollowsTest do
  @moduledoc false

  use ExUnit.Case

  @moduletag :skip

  alias PremiereEcoute.Twitch.History.Community.Unfollows
  alias PremiereEcoute.ExplorerCase

  @zip "priv/request-1.zip"

  test "count/2" do
    unfollows = Unfollows.count(@zip)

    assert unfollows == 1
  end

  test "all/2" do
    unfollows = Unfollows.all(@zip)

    assert ExplorerCase.equal_master?(unfollows, "unfollows")
  end
end
