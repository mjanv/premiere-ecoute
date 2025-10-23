defmodule PremiereEcoute.Apis.CurrencyConversionApi do
  @moduledoc """
  Currency conversion API client using Frankfurter.dev service.

  This module provides currency conversion functionality with support for
  different backend implementations through the Behaviour protocol.

  ## Examples

      iex> CurrencyConversionApi.convert("USD", 100)
      {:ok, %{amount: 100, base: "USD", date: "2025-10-23", rates: %{"EUR" => 92.5}}}

  """

  # AIDEV-NOTE: Uses Frankfurter.dev API for currency conversion; only EUR conversions supported
  use PremiereEcouteCore.Api, api: :currency_conversion

  @doc """
  Behaviour defining the interface for currency conversion implementations.
  This enables switching between different currency conversion backends.
  """
  defmodule Behaviour do
    @callback convert(from :: String.t(), amount :: number()) ::
                {:ok, map()} | {:error, term()}

    @callback get_latest_rates(from :: String.t()) ::
                {:ok, map()} | {:error, term()}
  end

  @doc """
  Creates a new API request client.
  """
  def api do
    [
      base_url: url(:api),
      headers: [
        {"Accept", "application/json"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> new()
  end

  @doc """
  Converts an amount from a given currency to EUR.

  ## Parameters

    - `from` - The source currency code (e.g., "USD", "GBP")
    - `amount` - The amount to convert (optional, defaults to 1)

  ## Examples

      iex> convert("USD", 100)
      {:ok, %{amount: 100, base: "USD", date: "2025-10-23", rates: %{"EUR" => 92.5}}}

  """
  defdelegate convert(from, amount \\ 1), to: __MODULE__.Conversion

  @doc """
  Gets the latest exchange rates from a given currency to EUR.

  ## Parameters

    - `from` - The source currency code (e.g., "USD", "GBP")

  ## Examples

      iex> get_latest_rates("USD")
      {:ok, %{amount: 1, base: "USD", date: "2025-10-23", rates: %{"EUR" => 0.925}}}

  """
  defdelegate get_latest_rates(from), to: __MODULE__.Conversion
end
