defmodule PremiereEcoute.Twitch.History.Commerce.BitsAcquired do
  @moduledoc false

  alias PremiereEcouteCore.Zipfile

  def read(file) do
    file
    |> Zipfile.csv("request/commerce/bits/bits_acquired.csv")
  end
end
