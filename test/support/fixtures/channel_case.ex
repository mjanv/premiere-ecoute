defmodule PremiereEcouteWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use PremiereEcouteWeb.ChannelCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Oban.Testing, repo: PremiereEcoute.Repo, prefix: "oban"

      import Phoenix.ChannelTest
      import PremiereEcouteWeb.ChannelCase

      @endpoint PremiereEcouteWeb.Endpoint

      import PremiereEcoute.AccountsFixtures
      import PremiereEcoute.Discography.AlbumFixtures
      import PremiereEcoute.Discography.PlaylistFixtures
      import PremiereEcoute.Sessions.ScoresFixtures

      import Swoosh.TestAssertions
    end
  end

  setup tags do
    PremiereEcoute.DataCase.setup_sandbox(tags)
    :ok
  end
end
