mocks = [
  twitch_api: PremiereEcoute.Apis.TwitchApi,
  spotify_api: PremiereEcoute.Apis.SpotifyApi
]

for {key, module} <- mocks do
  Mox.defmock(Module.concat([module, Mock]), for: Module.concat([module, Behavior]))
  Application.put_env(:premiere_ecoute, key, Module.concat([module, Mock]))
end

ExUnit.start(capture_log: true, exclude: [:api, :wip])
Ecto.Adapters.SQL.Sandbox.mode(PremiereEcoute.Repo, :manual)
