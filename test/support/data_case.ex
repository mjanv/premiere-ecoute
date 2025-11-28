defmodule PremiereEcoute.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use PremiereEcoute.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL

  using do
    quote do
      use Oban.Testing, repo: PremiereEcoute.Repo, prefix: "oban"

      import Ecto
      import Ecto.Changeset
      import Ecto.Query

      import PremiereEcoute.DataCase

      import PremiereEcoute.AccountsFixtures
      import PremiereEcoute.Discography.AlbumFixtures
      import PremiereEcoute.Discography.PlaylistFixtures
      import PremiereEcoute.Sessions.ListeningSessionFixtures
      import PremiereEcoute.Sessions.ScoresFixtures

      import Hammox
      import Swoosh.TestAssertions

      setup :set_mox_from_context
      setup :verify_on_exit!
      setup {Hammox, :verify_on_exit!}

      alias PremiereEcoute.Repo
    end
  end

  setup tags do
    PremiereEcoute.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Setup the Request test environment
  """
  @spec setup_req_test() :: :ok
  def setup_req_test do
    Req.Test.set_req_test_to_shared()
    Req.Test.verify_on_exit!()
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  @spec setup_sandbox(map()) :: :ok
  def setup_sandbox(tags) do
    pid = SQL.Sandbox.start_owner!(PremiereEcoute.Repo, shared: not tags[:async])
    on_exit(fn -> SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  @spec errors_on(Ecto.Changeset.t()) :: map()
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
