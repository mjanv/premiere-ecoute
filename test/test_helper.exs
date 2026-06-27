apis = [
  PremiereEcoute.Apis.MusicMetadata.GeniusApi,
  PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi,
  PremiereEcoute.Apis.MusicMetadata.WikipediaApi,
  PremiereEcoute.Apis.MusicProvider.DeezerApi,
  PremiereEcoute.Apis.MusicProvider.SpotifyApi,
  PremiereEcoute.Apis.MusicProvider.TidalApi,
  PremiereEcoute.Apis.Streaming.TwitchApi,
  PremiereEcoute.Apis.Video.YoutubeApi,
  PremiereEcoute.Accounts.Mailer,
  PremiereEcouteCore.CommandBus,
  PremiereEcoute.Sessions,
  PremiereEcoute.Wantlists
]

for api <- apis do
  Mox.defmock(Module.concat([api, Mock]), for: api.behaviours())
end

Mox.defmock(Boruta.OauthMock, for: Boruta.OauthModule)

ExUnit.start(capture_log: true, exclude: [:api, :wip, :skip])
Ecto.Adapters.SQL.Sandbox.mode(PremiereEcoute.Repo, :manual)
