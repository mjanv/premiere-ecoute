defmodule PremiereEcoute.Repo do
  @moduledoc """
  Primary database repository for the Premiere Ecoute application.

  Provides database access through Ecto with PostgreSQL adapter and includes pagination support via Scrivener. Contains utility functions for error handling and changeset processing.
  """

  use Ecto.Repo,
    otp_app: :premiere_ecoute,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 10

  @doc """
  Transforms changeset errors into human-readable messages.

  Traverses all errors in a changeset and interpolates placeholder values
  in error messages. Replaces patterns like `%{field}` with actual values
  from the error options.

  ## Examples

      iex> changeset = %Ecto.Changeset{errors: [{:email, {"must be %{count} characters", [count: 5]}}]}
      iex> traverse_errors(changeset)
      %{email: ["must be 5 characters"]}

  """
  @spec traverse_errors(Ecto.Changeset.t()) :: map()
  def traverse_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

defmodule PremiereEcoute.Repo.Vault do
  @moduledoc """
  Encryption vault for sensitive database fields using Cloak.

  Provides encryption and decryption capabilities for fields that need to be stored securely in the database, such as API tokens and credentials.
  """

  use Cloak.Vault, otp_app: :premiere_ecoute
end

defmodule PremiereEcoute.Repo.EncryptedField do
  @moduledoc """
  Ecto.Type to encrypt a binary field.
  """

  use Cloak.Ecto.Binary, vault: PremiereEcoute.Repo.Vault
end
