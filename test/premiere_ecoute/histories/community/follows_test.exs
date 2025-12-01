defmodule PremiereEcoute.Twitch.History.Community.FollowsTest do
  @moduledoc false

  use ExUnit.Case

  @moduletag :skip

  alias PremiereEcoute.Twitch.History.Community.Follows
  alias PremiereEcoute.ExplorerCase

  @zip "priv/request-1.zip"

  test "n/2" do
    follows = Follows.n(@zip)

    assert follows == 169
  end

  test "all/2" do
    follows = Follows.all(Follows.read(@zip))

    assert ExplorerCase.equal_master?(follows, "follows")
  end
end
