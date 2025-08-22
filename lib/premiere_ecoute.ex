defmodule PremiereEcoute do
  @moduledoc false

  use Boundary,
    deps: [PremiereEcouteCore],
    exports: [
      {Accounts, except: []},
      {Billboard, except: []},
      {Discography, except: []},
      {Events, except: []},
      {Sessions, except: []},
      {Apis, except: []},
      {Telemetry, except: []},
      PubSub,
      Repo
    ]

  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Mailer

  defdelegate apply(command), to: PremiereEcouteCore
  defdelegate paginate(stream, opts), to: Store

  def mailer, do: Mailer.impl()
end
