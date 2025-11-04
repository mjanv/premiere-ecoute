defmodule PremiereEcoute do
  @moduledoc false

  use Boundary,
    deps: [PremiereEcouteCore],
    exports: [
      {Apis, except: []},
      {Accounts, except: []},
      {Billboard, except: []},
      {Discography, except: []},
      {Donations, except: []},
      {Events, except: []},
      {Extension, except: []},
      {Festivals, except: []},
      {Playlists, except: []},
      {Sessions, except: []},
      {Telemetry, except: []},
      PubSub,
      Presence,
      Repo,
      DataCase,
      Version
    ]

  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Mailer

  @version Mix.Project.config()[:version]
  @commit System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) |> elem(0) |> String.trim()

  defdelegate apply(command), to: PremiereEcouteCore
  defdelegate paginate(stream, opts), to: Store

  def mailer, do: Mailer.impl()

  @doc "Returns the full version string in the format version-commit."
  def version, do: Enum.join([@version, @commit], "-")
end
