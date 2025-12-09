defmodule PremiereEcoute.Twitch.History.Ads.VideoAdRequest do
  @moduledoc false

  alias PremiereEcouteCore.Zipfile

  @doc "Reads video ad request data from a zip file."
  @spec read(String.t()) :: Explorer.DataFrame.t()
  def read(file) do
    file
    |> Zipfile.csv("request/ads/video_ad_impression.csv")
  end
end
