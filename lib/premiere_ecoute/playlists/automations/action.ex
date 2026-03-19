defmodule PremiereEcoute.Playlists.Automations.Action do
  @moduledoc """
  Behaviour for automation action implementations.

  Each action module implements `id/0`, `validate_config/1`, and `execute/3`.
  Actions are registered in `ActionRegistry` by their string id.
  """

  alias PremiereEcoute.Accounts.Scope

  @type config :: map()
  @type context :: map()
  @type output :: map()

  @doc "Unique string key used in playlist_automations.steps[].action_type"
  @callback id() :: String.t()

  @doc "Validates action-specific config; returns errors for UI form display"
  @callback validate_config(config()) :: :ok | {:error, [String.t()]}

  @doc "Executes the action; receives static config, pipeline context, and user scope"
  @callback execute(config(), context(), Scope.t()) :: {:ok, output()} | {:error, term()}
end
