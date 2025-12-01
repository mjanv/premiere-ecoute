defmodule PremiereEcoute.Twitch.History.SiteHistory.MinuteWatchedTest do
  @moduledoc false

  use ExUnit.Case

  @moduletag :skip

  alias PremiereEcoute.Twitch.History.SiteHistory.MinuteWatched
  alias PremiereEcoute.ExplorerCase

  @zip "priv/request-1.zip"

  test "read/2" do
    minute_watched = MinuteWatched.read(@zip)

    assert ExplorerCase.equal_master?(minute_watched, "minute_watched")
  end
end
