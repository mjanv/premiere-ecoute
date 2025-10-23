defmodule PremiereEcoute.BuyMeACoffee.DonationCreated do
  @moduledoc """
  Represents a "donation.created" webhook event from BuyMeACoffee.

  This event is triggered when a supporter makes a new donation.
  """

  # AIDEV-NOTE: Struct matches BuyMeACoffee webhook payload for donation.created event
  @type t :: %__MODULE__{
          type: String.t(),
          live_mode: boolean(),
          attempt: integer(),
          created: integer(),
          event_id: integer(),
          data: data()
        }

  @type data :: %{
          id: integer(),
          amount: number(),
          object: String.t(),
          status: String.t(),
          message: String.t(),
          currency: String.t(),
          refunded: String.t(),
          created_at: integer(),
          note_hidden: String.t(),
          refunded_at: integer() | nil,
          support_note: String.t(),
          support_type: String.t(),
          supporter_name: String.t(),
          supporter_name_type: String.t(),
          transaction_id: String.t(),
          application_fee: String.t(),
          supporter_id: integer(),
          supporter_email: String.t(),
          total_amount_charged: String.t(),
          coffee_count: integer(),
          coffee_price: number()
        }

  defstruct [
    :type,
    :live_mode,
    :attempt,
    :created,
    :event_id,
    :data
  ]

  @doc """
  Parses a webhook payload into a DonationCreated struct.

  ## Examples

      iex> parse(%{"type" => "donation.created", ...})
      {:ok, %DonationCreated{type: "donation.created", ...}}

      iex> parse(%{"invalid" => "payload"})
      {:error, :invalid_payload}
  """
  @spec parse(map()) :: {:ok, t()} | {:error, :invalid_payload}
  def parse(payload) when is_map(payload) do
    with {:ok, type} <- Map.fetch(payload, "type"),
         "donation.created" <- type do
      donation = %__MODULE__{
        type: payload["type"],
        live_mode: payload["live_mode"],
        attempt: payload["attempt"],
        created: payload["created"],
        event_id: payload["event_id"],
        data: parse_data(payload["data"])
      }

      {:ok, donation}
    else
      _ -> {:error, :invalid_payload}
    end
  end

  defp parse_data(data) when is_map(data) do
    %{
      id: data["id"],
      amount: data["amount"],
      object: data["object"],
      status: data["status"],
      message: data["message"],
      currency: data["currency"],
      refunded: data["refunded"],
      created_at: data["created_at"],
      note_hidden: data["note_hidden"],
      refunded_at: data["refunded_at"],
      support_note: data["support_note"],
      support_type: data["support_type"],
      supporter_name: data["supporter_name"],
      supporter_name_type: data["supporter_name_type"],
      transaction_id: data["transaction_id"],
      application_fee: data["application_fee"],
      supporter_id: data["supporter_id"],
      supporter_email: data["supporter_email"],
      total_amount_charged: data["total_amount_charged"],
      coffee_count: data["coffee_count"],
      coffee_price: data["coffee_price"]
    }
  end

  defp parse_data(_), do: nil
end
