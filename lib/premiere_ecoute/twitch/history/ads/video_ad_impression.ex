defmodule PremiereEcoute.Twitch.History.Ads.VideoAdImpression do
  @moduledoc false

  alias PremiereEcouteCore.Zipfile

  def read(file) do
    file
    |> Zipfile.csv("request/ads/video_ad_impression.csv")
  end
end
