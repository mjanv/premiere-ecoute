defmodule PremiereEcouteCore.FileStorage.Behaviour do
  @moduledoc false

  @callback create(origin :: String.t(), destination :: String.t()) :: :ok | :error
  @callback read(origin :: String.t(), destination :: String.t()) :: :ok | :error
  @callback delete(origin :: String.t()) :: :ok | :error
end
