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
      PubSub
    ]

  alias PremiereEcoute.Core
  alias PremiereEcoute.EventStore

  defdelegate apply(command), to: Core
  defdelegate paginate(stream, opts), to: EventStore
end
