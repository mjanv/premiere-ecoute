defmodule PremiereEcoute.Apis.BuyMeACoffeeApi.Supporters do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Apis.BuyMeACoffeeApi
  alias PremiereEcoute.BuyMeACoffee.Donation

  @doc """
  Retrieves the list of one-time supporters.

  ## Examples

      iex> get_supporters()
      {:ok, [%Donation{...}, ...]}

      iex> get_supporters()
      {:error, :unauthorized}
  """
  @spec get_supporters() :: {:ok, [Donation.t()]} | {:error, term()}
  def get_supporters do
    BuyMeACoffeeApi.api()
    |> BuyMeACoffeeApi.get(url: "/v1/supporters")
    |> BuyMeACoffeeApi.handle(200, &parse_supporters/1)
  end

  defp parse_supporters(%{"data" => supporters}) when is_list(supporters) do
    Enum.map(supporters, &Donation.parse/1)
  end

  defp parse_supporters(_), do: []
end
