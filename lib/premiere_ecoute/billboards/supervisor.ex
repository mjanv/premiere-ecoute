defmodule PremiereEcoute.Billboards.Supervisor do
  @moduledoc """
  Billboards subservice.
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      {PremiereEcouteCore.Cache, name: :billboards}
    ]
end
