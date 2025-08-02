defmodule PremiereEcoute do
  @moduledoc false

  use Boundary,
    deps: [],
    exports: [
      {Core, except: []},
      {Accounts, except: []},
      {Sessions, except: []},
      {Apis, except: []},
      {Telemetry, except: []},
      PubSub,
      DataCase
    ]

  alias PremiereEcoute.Core
  alias PremiereEcoute.EventStore
  alias PremiereEcoute.Mailer

  defdelegate apply(command), to: Core
  defdelegate paginate(stream, opts), to: EventStore

  def mailer, do: Mailer.impl()
end
