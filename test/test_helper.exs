Mox.defmock(PremiereEcoute.Apis.SpotifyApiMock, for: PremiereEcoute.Apis.SpotifyApi.Behavior)
Application.put_env(:premiere_ecoute, :spotify_api, PremiereEcoute.Apis.SpotifyApiMock)

ExUnit.start(exclude: [:spotify])
Ecto.Adapters.SQL.Sandbox.mode(PremiereEcoute.Repo, :manual)
