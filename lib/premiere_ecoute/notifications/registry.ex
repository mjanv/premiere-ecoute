defmodule PremiereEcoute.Notifications.Registry do
  @moduledoc """
  Compile-time registry of notification types.

  Add new type modules to @types below. Keys are derived automatically:
  - by struct module for dispatch (struct → module)
  - by type string for DB reload (string → module)
  """

  # AIDEV-NOTE: add new notification type modules here; keys are built from the module itself
  @types [
    PremiereEcoute.Notifications.Types.AutomationFailure,
    PremiereEcoute.Notifications.Types.AutomationSuccess
  ]

  @by_module Map.new(@types, fn mod -> {mod, mod} end)
  @by_string Map.new(@types, fn mod -> {mod.type(), mod} end)

  @doc "Looks up a type module by notification struct. Used at dispatch time."
  @spec get(struct()) :: {:ok, module()} | :error
  def get(%mod{}), do: Map.fetch(@by_module, mod)

  @doc "Looks up a type module by type string. Used when reloading from DB."
  @spec get_by_string(String.t()) :: {:ok, module()} | :error
  def get_by_string(type), do: Map.fetch(@by_string, type)

  @doc "Returns all registered type modules keyed by type string"
  @spec all() :: %{String.t() => module()}
  def all, do: @by_string
end
