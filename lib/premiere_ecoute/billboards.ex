defmodule PremiereEcoute.Billboards do
  @moduledoc false

  alias PremiereEcoute.Billboards.Billboard
  alias PremiereEcoute.Billboards.Services.BillboardCreation
  alias PremiereEcoute.Utils.GoofyWords
  alias PremiereEcouteCore.Cache

  defdelegate generate_billboard(playlist_urls, opts), to: BillboardCreation
  defdelegate all(clauses), to: Billboard
  def get_billboard(billboard_id), do: Billboard.get_by(billboard_id: billboard_id)
  defdelegate create_billboard(billboard), to: Billboard, as: :create
  defdelegate update_billboard(billboard, attrs), to: Billboard, as: :update
  defdelegate delete_billboard(billboard), to: Billboard, as: :delete
  defdelegate change_billboard(billboard, attrs \\ %{}), to: Billboard, as: :changeset

  def add_submission(billboard, url, pseudo \\ "")

  def add_submission(%Billboard{status: :active} = billboard, url, pseudo) when is_binary(url) do
    if Enum.any?(billboard.submissions, fn s -> s["url"] == url end) do
      {:error, :url_already_exists}
    else
      # Generate a unique token for this submission
      deletion_token = GoofyWords.generate_with_number()

      submission = %{
        url: url,
        pseudo: pseudo,
        submitted_at: DateTime.utc_now(),
        deletion_token: deletion_token
      }

      case update_billboard(billboard, %{submissions: [submission | billboard.submissions]}) do
        {:ok, updated_billboard} ->
          Cache.del(:billboards, updated_billboard.billboard_id)
          {:ok, updated_billboard, deletion_token}

        error ->
          error
      end
    end
  end

  def add_submission(%Billboard{}, _, _), do: {:error, :billboard_not_active}

  def remove_submission(%Billboard{} = billboard, index) when is_integer(index) do
    if index >= 0 and index < length(billboard.submissions) do
      case update_billboard(billboard, %{submissions: List.delete_at(billboard.submissions, index)}) do
        {:ok, updated_billboard} ->
          Cache.del(:billboards, updated_billboard.billboard_id)
          {:ok, updated_billboard}

        error ->
          error
      end
    else
      {:error, :invalid_index}
    end
  end

  @doc """
  Removes a submission by its deletion token.
  """
  def remove_submission_by_token(%Billboard{} = billboard, token) when is_binary(token) do
    case Enum.find_index(billboard.submissions, fn submission ->
           case submission do
             %{deletion_token: ^token} -> true
             %{"deletion_token" => ^token} -> true
             _ -> false
           end
         end) do
      nil -> {:error, :token_not_found}
      index -> remove_submission(billboard, index)
    end
  end

  def activate_billboard(%Billboard{} = billboard), do: update_billboard(billboard, %{status: :active})
  def stop_billboard(%Billboard{} = billboard), do: update_billboard(billboard, %{status: :stopped})
end
