defmodule PremiereEcoute do
  @moduledoc false

  use Boundary,
    deps: [PremiereEcouteCore],
    exports: [
      {Apis, except: []},
      {Accounts, except: []},
      {Billboard, except: []},
      {Discography, except: []},
      {Events, except: []},
      {Extension, except: []},
      {Festivals, except: []},
      {Playlists, except: []},
      {Sessions, except: []},
      {Telemetry, except: []},
      PubSub,
      Presence,
      Repo,
      DataCase
    ]

  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Mailer

  defdelegate apply(command), to: PremiereEcouteCore
  defdelegate paginate(stream, opts), to: Store

  def mailer, do: Mailer.impl()
end
