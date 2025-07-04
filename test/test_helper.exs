Mox.defmock(PremiereEcoute.Apis.TwitchApiMock, for: PremiereEcoute.Apis.TwitchApi.Behavior)
Application.put_env(:premiere_ecoute, :twitch_api, PremiereEcoute.Apis.TwitchApiMock)

Mox.defmock(PremiereEcoute.Apis.SpotifyApiMock, for: PremiereEcoute.Apis.SpotifyApi.Behavior)
Application.put_env(:premiere_ecoute, :spotify_api, PremiereEcoute.Apis.SpotifyApiMock)

ExUnit.start(capture_log: true, exclude: [:spotify])
Ecto.Adapters.SQL.Sandbox.mode(PremiereEcoute.Repo, :manual)
