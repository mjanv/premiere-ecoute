defmodule PremiereEcoute.Twitch.History.Commerce.BitsAcquired do
  @moduledoc false

  alias PremiereEcouteCore.Zipfile

  @doc "Reads bits acquired data from a zip file."
  @spec read(String.t()) :: Explorer.DataFrame.t()
  def read(file) do
    file
    |> Zipfile.csv("request/commerce/bits/bits_acquired.csv")
  end
end
