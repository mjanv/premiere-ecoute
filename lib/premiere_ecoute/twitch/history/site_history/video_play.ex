defmodule PremiereEcoute.Twitch.History.SiteHistory.VideoPlay do
  @moduledoc false

  alias PremiereEcouteCore.Zipfile

  def read(file) do
    file
    |> Zipfile.csv("request/site_history/video_play.csv")
  end
end
