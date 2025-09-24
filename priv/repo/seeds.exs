require Logger

defmodule Seeds do
  def password(n \\ 10), do: for(_ <- 1..n, into: "", do: <<Enum.random(~c"0123456789abcdefghijklmnopqrstuvwxyz")>>)
  def user_id(n \\ 10), do: for(_ <- 1..n, into: "", do: <<Enum.random(~c"0123456789abcdef")>>)
  def token(n \\ 32), do: Base.url_encode64(:crypto.strong_rand_bytes(n), padding: false)
end

# Feature flags
PremiereEcouteCore.FeatureFlag.enable(:billboards)
PremiereEcouteCore.FeatureFlag.enable(:listening_sessions)
PremiereEcouteCore.FeatureFlag.enable(:listening_session_playlist)
PremiereEcouteCore.FeatureFlag.enable(:follow_channels)
PremiereEcouteCore.FeatureFlag.enable(:playlists)
PremiereEcouteCore.FeatureFlag.enable(:playlist_workflows)
PremiereEcouteCore.FeatureFlag.enable(:festivals)

# Accounts
Logger.info(IO.ANSI.green() <> IO.ANSI.bright() <> "Accounts:" <> IO.ANSI.reset())

for i <- 1..2 do
  password = Seeds.user_id()

  payload = %{
    user_id: Seeds.user_id(),
    email: "streamer#{i}@provider.fr",
    username: "streamer#{i}",
    display_name: "Streamer Name",
    broadcaster_type: "partner",
    access_token: Seeds.token(32),
    refresh_token: Seeds.token(32),
    expires_in: 3600
  }

  {:ok, streamer} = PremiereEcoute.Accounts.Services.AccountRegistration.register_twitch_user(payload, password)

  Logger.info(
    IO.ANSI.green() <> "  Created streamer account with email '#{streamer.email}' and password '#{password}'" <> IO.ANSI.reset()
  )
end

for i <- 1..2 do
  password = Seeds.user_id()

  payload = %{
    user_id: Seeds.user_id(),
    email: "viewer#{i}@provider.fr",
    username: "viewer#{i}",
    display_name: "Viewer Name",
    broadcaster_type: "",
    access_token: Seeds.token(32),
    refresh_token: Seeds.token(32),
    expires_in: 3600
  }

  {:ok, viewer} = PremiereEcoute.Accounts.Services.AccountRegistration.register_twitch_user(payload, password)

  Logger.info(
    IO.ANSI.green() <> "  Created viewer account with email '#{viewer.email}' and password '#{password}'" <> IO.ANSI.reset()
  )
end
