defmodule PremiereEcoute.Apis.Payments.FrankfurterApi.Conversion do
  @moduledoc """
  Handles currency conversion operations using the Frankfurter.dev API.

  This module implements the actual API calls for converting currencies to EUR.
  """

  alias PremiereEcoute.Apis.Payments.FrankfurterApi

  @doc """
  Converts an amount from a given currency to EUR or another target currency using today's exchange rate.

  ## Parameters
    - `%{amount: number(), currency: String.t()}` - Converts to EUR (default)
    - `%{amount: number(), from: String.t(), to: String.t()}` - Converts from one currency to another

  ## Examples
      iex> convert(%{amount: 100, currency: "USD"})
      {:ok, %{amount: 92.5, currency: "EUR"}}

      iex> convert(%{amount: 100, from: "USD", to: "GBP"})
      {:ok, %{amount: 75.0, currency: "GBP"}}
  """
  @spec convert(%{amount: number(), currency: String.t()}) ::
          {:ok, %{amount: number(), currency: String.t()}} | {:error, term()}
  def convert(%{amount: amount, currency: from}) when is_number(amount) and is_binary(from) do
    convert(%{amount: amount, from: from, to: "EUR"})
  end

  @spec convert(%{amount: number(), from: String.t(), to: String.t()}) ::
          {:ok, %{amount: number(), currency: String.t()}} | {:error, term()}
  def convert(%{amount: amount, from: from, to: to}) when is_number(amount) and is_binary(from) and is_binary(to) do
    to_upper = String.upcase(to)

    FrankfurterApi.api()
    |> FrankfurterApi.get(url: "/latest", params: %{from: String.upcase(from), to: to_upper, amount: amount})
    |> FrankfurterApi.handle(200, &parse_conversion_response(&1, to_upper))
  end

  defp parse_conversion_response(%{"rates" => %{} = rates}, to_currency) when is_map(rates) do
    # Get the amount for the target currency
    # If not found, this will cause a function clause error which the handle/3 will catch
    amount = Map.fetch!(rates, to_currency)
    %{amount: amount, currency: to_currency}
  end
end
