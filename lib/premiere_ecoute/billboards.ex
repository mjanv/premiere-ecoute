defmodule PremiereEcoute.Billboards do
  @moduledoc false

  alias PremiereEcoute.Billboards.Billboard
  alias PremiereEcoute.Billboards.Services.BillboardCreation

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
      submission = %{url: url, pseudo: pseudo, submitted_at: DateTime.utc_now()}
      update_billboard(billboard, %{submissions: [submission | billboard.submissions]})
    end
  end

  def add_submission(%Billboard{}, _, _), do: {:error, :billboard_not_active}

  def remove_submission(%Billboard{} = billboard, index) when is_integer(index) do
    if index >= 0 and index < length(billboard.submissions) do
      update_billboard(billboard, %{submissions: List.delete_at(billboard.submissions, index)})
    else
      {:error, :invalid_index}
    end
  end

  def activate_billboard(%Billboard{} = billboard), do: update_billboard(billboard, %{status: :active})
  def stop_billboard(%Billboard{} = billboard), do: update_billboard(billboard, %{status: :stopped})

  @doc """
  Generates a billboard for display using the existing Billboard service.
  """
  def generate_billboard_display(%Billboard{submissions: submissions}) when is_list(submissions) do
    urls =
      submissions
      |> Enum.map(fn
        %{url: url} -> url
        %{"url" => url} -> url
        url when is_binary(url) -> url
      end)
      |> Enum.filter(&is_binary/1)

    case urls do
      [] -> {:error, :no_submissions}
      urls -> generate_billboard(urls, [])
    end
  end

  def generate_billboard_display(_), do: {:error, :no_submissions}
end
