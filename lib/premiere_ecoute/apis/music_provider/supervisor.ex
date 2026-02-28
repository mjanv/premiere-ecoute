defmodule PremiereEcoute.Apis.MusicProvider.Supervisor do
  @moduledoc """
  Apis Music provider subservice.
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      PremiereEcoute.Apis.MusicProvider.SpotifyApi.Gateway
    ]
end
