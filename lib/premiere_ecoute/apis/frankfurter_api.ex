defmodule PremiereEcoute.Apis.FrankfurterApi do
  @moduledoc """
  Frankfurter conversion API client using Frankfurter.dev service.

  This module provides currency conversion functionality to EUR with support for
  different backend implementations through the Behaviour protocol.

  ## Examples

      iex> FrankfurterApi.convert(%{amount: 100, currency: "USD"})
      {:ok, %{amount: 92.5, currency: "EUR"}}

  """

  use PremiereEcouteCore.Api, api: :frankfurter

  defmodule Behaviour do
    @moduledoc "Frankfurter API behaviour."

    @callback convert(params :: %{amount: number(), currency: String.t()}) ::
                {:ok, %{amount: number(), currency: String.t()}} | {:error, term()}
    @callback convert(params :: %{amount: number(), from: String.t(), to: String.t()}) ::
                {:ok, %{amount: number(), currency: String.t()}} | {:error, term()}
    @callback client_credentials() :: {:ok, map()} | {:error, any()}
  end

  @doc """
  Creates a Req client for Frankfurter API.

  Configures base URL and JSON headers. No authentication required as Frankfurter is a free public API.
  """
  @spec api :: Req.Request.t()
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
  Returns public client credentials.

  Frankfurter is a free public API requiring no authentication. Returns placeholder credentials for compatibility with the API base module.
  """
  @spec client_credentials :: {:ok, %{String.t() => String.t() | integer()}}
  def client_credentials, do: {:ok, %{"access_token" => "public", "expires_in" => 3_600}}

  defdelegate convert(params), to: __MODULE__.Conversion
end
