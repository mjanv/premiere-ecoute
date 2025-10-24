defmodule PremiereEcoute.Apis.BuyMeACoffeeApi do
  @moduledoc """
  # BuyMeACoffee API Client

  Client for BuyMeACoffee API integration providing access to supporter donation data.
  This module handles authentication via API key and provides methods to retrieve
  supporter information.

  ## Supporters

  Retrieves lists of one-time supporters who have made donations. Returns donation
  records with supporter information, payment details, and support messages.
  """

  use PremiereEcouteCore.Api, api: :buymeacoffee

  alias PremiereEcoute.Events.BuyMeACoffee.Donation

  defmodule Behaviour do
    @moduledoc "BuyMeACoffee API Behaviour"

    alias PremiereEcoute.Events.BuyMeACoffee.Donation

    @callback get_supporters() :: {:ok, [Donation.t()]} | {:error, term()}
  end

  @spec api :: Req.Request.t()
  def api do
    api_key = Application.get_env(:premiere_ecoute, :buymeacoffee_api_key)

    [
      base_url: url(:api),
      headers: [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> new()
  end

  @spec client_credentials() :: {:ok, %{String.t() => String.t() | integer()}}
  def client_credentials, do: {:ok, %{"access_token" => "", "expires_in" => 0}}

  # Supporters
  defdelegate get_supporters, to: __MODULE__.Supporters
end
