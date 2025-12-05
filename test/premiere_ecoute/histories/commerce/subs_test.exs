defmodule PremiereEcoute.Twitch.History.Commerce.SubscriptionsTest do
  @moduledoc false

  use ExUnit.Case

  @moduletag :skip

  alias PremiereEcoute.ExplorerCase
  alias PremiereEcoute.Twitch.History.Commerce.Subscriptions

  @zip "priv/request-1.zip"

  test "read/2" do
    subscriptions = Subscriptions.read(@zip)

    assert ExplorerCase.equal_master?(subscriptions, "subs")
  end
end
