defmodule PremiereEcoute.Accounts.Supervisor do
  @moduledoc """
  Accounts subservice.

  Manages the users cache and optional services.
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      {PremiereEcouteCore.Cache, name: :users, persist: false}
    ]
end
