defmodule PremiereEcoute.Apis.FrankfurterApi.Conversion do
  @moduledoc """
  Handles currency conversion operations using the Frankfurter.dev API.

  This module implements the actual API calls for converting currencies to EUR.
  """

  alias PremiereEcoute.Apis.FrankfurterApi

  @doc """
  Converts an amount from a given currency to EUR using today's exchange rate.
  """
  @spec convert(%{amount: number(), currency: String.t()}) ::
          {:ok, %{amount: number(), currency: String.t()}} | {:error, term()}
  def convert(%{amount: amount, currency: from}) when is_number(amount) and is_binary(from) do
    FrankfurterApi.api()
    |> FrankfurterApi.get(url: "/latest", params: %{from: String.upcase(from), to: "EUR", amount: amount})
    |> FrankfurterApi.handle(200, &parse_conversion_response/1)
  end

  defp parse_conversion_response(%{"rates" => %{"EUR" => amount}}) when is_number(amount) do
    %{amount: amount, currency: "EUR"}
  end
end
