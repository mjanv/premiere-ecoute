defmodule PremiereEcoute.Apis.CurrencyApi do
  @moduledoc """
  Currency conversion API client using Frankfurter.dev service.

  This module provides currency conversion functionality to EUR with support for
  different backend implementations through the Behaviour protocol.

  ## Examples

      iex> CurrencyApi.convert(%{amount: 100, currency: "USD"})
      {:ok, %{amount: 92.5, currency: "EUR"}}

  """

  # AIDEV-NOTE: Uses Frankfurter.dev API for currency conversion; only EUR conversions supported
  use PremiereEcouteCore.Api, api: :currency

  @doc """
  Behaviour defining the interface for currency conversion implementations.
  This enables switching between different currency conversion backends.
  """
  defmodule Behaviour do
    @callback convert(params :: %{amount: number(), currency: String.t()}) ::
                {:ok, %{amount: number(), currency: String.t()}} | {:error, term()}
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

    - `params` - Map with:
      - `:amount` - The amount to convert (number)
      - `:currency` - The source currency code (e.g., "USD", "GBP")

  ## Returns

    - `{:ok, %{amount: number, currency: "EUR"}}` - Converted amount in EUR
    - `{:error, term}` - Error details

  ## Examples

      iex> convert(%{amount: 100, currency: "USD"})
      {:ok, %{amount: 92.5, currency: "EUR"}}

      iex> convert(%{amount: 50, currency: "GBP"})
      {:ok, %{amount: 59.75, currency: "EUR"}}

  """
  defdelegate convert(params), to: __MODULE__.Conversion
end
