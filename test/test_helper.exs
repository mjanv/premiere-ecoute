apis = [PremiereEcoute.Apis.Streaming.TwitchApi, PremiereEcoute.Apis.MusicProvider.SpotifyApi, PremiereEcoute.Accounts.Mailer]

for api <- apis do
  Mox.defmock(Module.concat([api, Mock]), for: Module.concat([api, Behaviour]))
end

ExUnit.start(capture_log: true, exclude: [:api, :wip])
Ecto.Adapters.SQL.Sandbox.mode(PremiereEcoute.Repo, :manual)
