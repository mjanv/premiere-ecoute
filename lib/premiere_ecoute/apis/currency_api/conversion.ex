defmodule PremiereEcoute.Apis.CurrencyApi.Conversion do
  @moduledoc """
  Handles currency conversion operations using the Frankfurter.dev API.

  This module implements the actual API calls for converting currencies to EUR.
  """

  require Logger
  alias PremiereEcoute.Apis.CurrencyApi

  @doc """
  Converts an amount from a given currency to EUR using today's exchange rate.

  ## Parameters

    - `params` - Map with:
      - `:amount` - The amount to convert (number)
      - `:currency` - The source currency code (e.g., "USD", "GBP")

  ## Returns

    - `{:ok, %{amount: number, currency: "EUR"}}` - Converted amount in EUR
    - `{:error, term}` - Error details

  ## Examples

      iex> convert(%{amount: 100, currency: "USD"})
      {:ok, %{amount: 92.5, currency: "EUR"}}

  """
  @spec convert(%{amount: number(), currency: String.t()}) ::
          {:ok, %{amount: number(), currency: String.t()}} | {:error, term()}
  def convert(%{amount: amount, currency: from_currency})
      when is_number(amount) and is_binary(from_currency) do
    # AIDEV-NOTE: Frankfurter API supports amount parameter; only EUR target supported per requirements
    params = %{
      from: String.upcase(from_currency),
      to: "EUR",
      amount: amount
    }

    CurrencyApi.api()
    |> CurrencyApi.get(url: "/latest", params: params)
    |> CurrencyApi.handle(200, &parse_conversion_response/1)
  end

  # AIDEV-NOTE: Parser extracts EUR rate and calculates converted amount
  defp parse_conversion_response(%{"rates" => %{"EUR" => eur_amount}})
       when is_number(eur_amount) do
    %{
      amount: eur_amount,
      currency: "EUR"
    }
  end

  defp parse_conversion_response(body) do
    Logger.warning("Unexpected currency conversion response format: #{inspect(body)}")
    raise "Unexpected response format"
  end
end
