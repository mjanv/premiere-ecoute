defmodule PremiereEcoute do
  @moduledoc """
  PremiereEcoute domain layer public API.

  Exposes core business modules (Apis, Accounts, Playlists, Sessions, etc.) and provides delegation to the underlying command and event infrastructure.
  """

  use Boundary,
    deps: [PremiereEcouteCore],
    exports: [
      {Apis, except: []},
      {Accounts, except: []},
      {Billboard, except: []},
      {Commands, except: []},
      {Discography, except: []},
      {Donations, except: []},
      {Events, except: []},
      {Extension, except: []},
      {Festivals, except: []},
      {Playlists, except: []},
      {Radio, except: []},
      {Sessions, except: []},
      {Telemetry, except: []},
      {Twitch, except: []},
      PubSub,
      Presence,
      Repo,
      DataCase,
      ExplorerCase
    ]

  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Mailer

  @version Mix.Project.config()[:version]
  @commit System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) |> elem(0) |> String.trim()

  defdelegate apply(command), to: PremiereEcouteCore
  defdelegate paginate(stream, opts), to: Store

  @doc "Returns mailer"
  @spec mailer() :: atom()
  def mailer, do: Mailer.impl()

  @doc "Returns the full version string in the format version-commit."
  @spec version() :: String.t()
  def version, do: Enum.join([@version, @commit], "-")

  @doc "Returns the upload directory"
  @spec uploads_dir() :: String.t()
  def uploads_dir, do: Path.join([:code.priv_dir(:premiere_ecoute), "uploads"])

  @doc """
  Returns the absolute path to a specific uploaded file by ID.
  """
  @spec file_path(binary()) :: String.t()
  def file_path(id) when is_binary(id) do
    Path.join(uploads_dir(), "#{id}.zip")
  end
end
