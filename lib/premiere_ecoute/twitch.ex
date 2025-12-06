defmodule PremiereEcoute.Twitch do
  @moduledoc false

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Twitch
  alias PremiereEcoute.Twitch.History

  def file_storage, do: PremiereEcouteCore.FileStorage.Filesystem

  @doc "Create a new history"
  @spec create_history(String.t(), History.t()) :: {:ok, History.t()} | {:error, String.t()}
  def create_history(path, user) do
    with %History{} = history <- History.read(path),
         destination <- Path.join(user.id, history.request_id <> ".zip"),
         :ok <- Twitch.file_storage().create(path, destination) do
      {:ok, history}
    else
      _reason -> {:error, "Cannot create history"}
    end
  end

  @doc "Delete a history"
  @spec delete_history(String.t(), User.t()) :: {:ok, String.t()} | {:error, String.t()}
  def delete_history(request_id, user) do
    with origin <- Path.join(user.id, request_id <> ".zip"),
         :ok <- Twitch.file_storage().delete(origin) do
      {:ok, request_id}
    else
      _ -> {:error, "Cannot delete history"}
    end
  end
end
