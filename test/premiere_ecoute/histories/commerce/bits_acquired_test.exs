defmodule PremiereEcoute.Twitch.History.Commerce.BitsAcquiredTest do
  @moduledoc false

  use ExUnit.Case

  @moduletag :skip

  alias PremiereEcoute.Twitch.History.Commerce.BitsAcquired

  @zip "priv/request-1.zip"

  test "read/2" do
    bits = BitsAcquired.read(@zip)

    assert Explorer.DataFrame.shape(bits) == {0, 22}
  end
end
