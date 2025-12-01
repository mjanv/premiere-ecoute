defmodule PremiereEcoute.Twitch.History.Commerce.BitsCheered do
  @moduledoc false

  alias PremiereEcouteCore.Zipfile

  def read(file) do
    file
    |> Zipfile.csv("request/commerce/bits/bits_cheered.csv")
  end
end
