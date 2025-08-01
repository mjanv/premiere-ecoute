for api <- [PremiereEcoute.Apis.TwitchApi, PremiereEcoute.Apis.SpotifyApi] do
  Mox.defmock(Module.concat([api, Mock]), for: Module.concat([api, Behavior]))
end

ExUnit.start(capture_log: true, exclude: [:api, :wip])
Ecto.Adapters.SQL.Sandbox.mode(PremiereEcoute.Repo, :manual)
