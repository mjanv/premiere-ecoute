apis = [
  PremiereEcoute.Apis.Streaming.TwitchApi,
  PremiereEcoute.Apis.MusicProvider.SpotifyApi,
  PremiereEcoute.Apis.MusicProvider.DeezerApi,
  PremiereEcoute.Accounts.Mailer,
  PremiereEcouteCore.CommandBus,
  PremiereEcoute.Sessions
]

for api <- apis do
  Mox.defmock(Module.concat([api, Mock]), for: api.behaviours())
end

ExUnit.start(capture_log: true, exclude: [:api, :wip])
Ecto.Adapters.SQL.Sandbox.mode(PremiereEcoute.Repo, :manual)
