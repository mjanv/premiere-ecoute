apis = [PremiereEcoute.Apis.TwitchApi, PremiereEcoute.Apis.SpotifyApi, PremiereEcoute.Mailer]

for api <- apis do
  Mox.defmock(Module.concat([api, Mock]), for: Module.concat([api, Behaviour]))
end

ExUnit.start(capture_log: true, exclude: [:api, :wip])
Ecto.Adapters.SQL.Sandbox.mode(PremiereEcoute.Repo, :manual)
