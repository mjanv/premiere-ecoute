defmodule PremiereEcoute.Twitch.History.SiteHistory.VideoPlay do
  @moduledoc false

  alias PremiereEcouteCore.Zipfile

  @doc "Reads video play data from a zip file."
  @spec read(String.t()) :: Explorer.DataFrame.t()
  def read(file) do
    file
    |> Zipfile.csv("request/site_history/video_play.csv")
  end
end
