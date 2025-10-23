defmodule PremiereEcoute.Apis.CurrencyConversionApi.Conversion do
  @moduledoc """
  Handles currency conversion operations using the Frankfurter.dev API.

  This module implements the actual API calls for converting currencies to EUR.
  """

  require Logger
  alias PremiereEcoute.Apis.CurrencyConversionApi

  @doc """
  Converts an amount from a given currency to EUR using today's exchange rate.

  ## Parameters

    - `from` - The source currency code (e.g., "USD", "GBP")
    - `amount` - The amount to convert (defaults to 1)

  ## Returns

    - `{:ok, map}` with conversion data including rate and converted amount
    - `{:error, term}` on failure

  ## Examples

      iex> convert("USD", 100)
      {:ok, %{amount: 100, base: "USD", date: "2025-10-23", rates: %{"EUR" => 92.5}}}

  """
  @spec convert(String.t(), number()) :: {:ok, map()} | {:error, term()}
  def convert(from, amount \\ 1) when is_binary(from) and is_number(amount) do
    # AIDEV-NOTE: Frankfurter API supports amount parameter; only EUR target supported per requirements
    params = %{
      from: String.upcase(from),
      to: "EUR",
      amount: amount
    }

    CurrencyConversionApi.api()
    |> CurrencyConversionApi.get(url: "/latest", params: params)
    |> CurrencyConversionApi.handle(200, &parse_conversion_response/1)
  end

  @doc """
  Gets the latest exchange rates from a given currency to EUR.

  This is equivalent to calling `convert/2` with amount = 1.

  ## Parameters

    - `from` - The source currency code (e.g., "USD", "GBP")

  ## Returns

    - `{:ok, map}` with rate data
    - `{:error, term}` on failure

  ## Examples

      iex> get_latest_rates("USD")
      {:ok, %{amount: 1, base: "USD", date: "2025-10-23", rates: %{"EUR" => 0.925}}}

  """
  @spec get_latest_rates(String.t()) :: {:ok, map()} | {:error, term()}
  def get_latest_rates(from) when is_binary(from) do
    convert(from, 1)
  end

  # AIDEV-NOTE: Parser validates expected response structure from Frankfurter API
  defp parse_conversion_response(%{
         "amount" => amount,
         "base" => base,
         "date" => date,
         "rates" => rates
       })
       when is_map(rates) do
    %{
      amount: amount,
      base: base,
      date: date,
      rates: rates
    }
  end

  defp parse_conversion_response(body) do
    Logger.warning("Unexpected currency conversion response format: #{inspect(body)}")
    raise "Unexpected response format"
  end
end
