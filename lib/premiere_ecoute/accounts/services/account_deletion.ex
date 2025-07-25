defmodule PremiereEcoute.Accounts.Services.AccountDeletion do
  @moduledoc false

  alias PremiereEcoute.Accounts.User

  @spec delete_account(User.t()) :: :ok
  def delete_account(_user) do
    :ok
  end

  @spec delete_associated_data(User.t()) :: :ok
  def delete_associated_data(_user) do
    :ok
  end
end
