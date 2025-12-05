defmodule PremiereEcoute.Twitch.History.Channels do
  @moduledoc false

  alias PremiereEcoute.Twitch.History.Community
  alias PremiereEcoute.Twitch.History.SiteHistory

  def channels(file) do
    a =
      file
      |> SiteHistory.MinuteWatched.read()
      |> SiteHistory.MinuteWatched.group_channel()

    b =
      file
      |> SiteHistory.ChatMessages.read()
      |> SiteHistory.ChatMessages.group_channel()

    c =
      file
      |> Community.Follows.read()
      |> Community.Follows.all()

    a
    |> Explorer.DataFrame.join(b, how: :left, on: [:channel])
    |> Explorer.DataFrame.join(c, how: :left, on: [:channel])
  end
end
