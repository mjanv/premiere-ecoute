defmodule PremiereEcoute.Apis.Payments.BuyMeACoffeeApi.Supporters do
  @moduledoc """
  Buy Me a Coffee supporters API.

  Fetches one-time supporters from the Buy Me a Coffee API and parses them into Donation events.
  """

  require Logger

  alias PremiereEcoute.Apis.Payments.BuyMeACoffeeApi
  alias PremiereEcoute.Events.BuyMeACoffee.Donation

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
