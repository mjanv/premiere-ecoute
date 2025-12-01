# ---- Ads ----
# PremiereEcoute.Twitch.History.Ads.VideoAdImpression.read("priv/request-1.zip") |> IO.inspect()
# PremiereEcoute.Twitch.History.Ads.VideoAdRequest.read("priv/request-1.zip") |> IO.inspect()

# ---- Commerce ----
# PremiereEcoute.Twitch.History.Commerce.BitsAcquired.read("priv/request-1.zip") |> IO.inspect()
# PremiereEcoute.Twitch.History.Commerce.BitsCheered.read("priv/request-1.zip") |> IO.inspect()
PremiereEcoute.Twitch.History.Commerce.Subscriptions.read("priv/request-1.zip") |> IO.inspect()

# ---- Community ----
# PremiereEcoute.Twitch.History.Community.Unfollows.read("priv/request-1.zip") |> IO.inspect()
# PremiereEcoute.Twitch.History.Community.Follows.read("priv/request-1.zip") |> IO.inspect()

# ----- Site history ----
# PremiereEcoute.Twitch.History.SiteHistory.ChatMessages.read("priv/request-1.zip") |> IO.inspect()
# PremiereEcoute.Twitch.History.SiteHistory.MinuteWatched.read("priv/request-1.zip") |> IO.inspect()
# PremiereEcoute.Twitch.History.SiteHistory.VideoPlay.read("priv/request-1.zip") |> IO.inspect()

# ---- Metadata ----
PremiereEcoute.Twitch.History.read("priv/request-1.zip") |> IO.inspect()
