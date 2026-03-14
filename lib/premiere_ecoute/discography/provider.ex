defmodule PremiereEcoute.Discography.Provider do
  @moduledoc """
  Embedded schema representing a provider identifier for a discography entity.

  A provider maps a platform name (e.g. `:spotify`, `:deezer`) to its platform-specific
  string ID. Stored as JSONB in `provider_ids` columns, allowing an entity to be linked
  to multiple providers simultaneously.

  ## Example

      %{"spotify" => "7aJuG4TFXa2hmE4z1yxc3n", "deezer" => "abc123"}

  Access a specific provider ID:

      Map.get(entity.provider_ids, :spotify)
      # => "7aJuG4TFXa2hmE4z1yxc3n"

  """

  @type t :: %{atom() => String.t()}

  @doc "Returns the ID for the given provider, or nil."
  @spec get(t(), atom()) :: String.t() | nil
  def get(provider_ids, provider) when is_map(provider_ids), do: Map.get(provider_ids, provider)

  @doc "Builds a provider_ids map from a single provider + id pair."
  @spec from(atom(), String.t()) :: t()
  def from(provider, id) when is_atom(provider) and is_binary(id), do: %{provider => id}
end
