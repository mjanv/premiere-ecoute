defmodule PremiereEcouteWeb.Webhooks.BuyMeACoffeeController do
  use PremiereEcouteWeb, :controller

  require Logger

  alias PremiereEcoute.Donations
  alias PremiereEcoute.Events.BuyMeACoffee.DonationCreated
  alias PremiereEcoute.Events.BuyMeACoffee.DonationRefunded
  alias PremiereEcoute.Telemetry.ApiMetrics

  def handle(conn, _params) do
    event_type = get_in(conn.body_params, ["type"])
    ApiMetrics.webhook_event(:buymeacoffee, event_type)

    case handle_event(conn.body_params) do
      {:ok, %DonationCreated{} = event} ->
        case create_donation_record(event, conn.body_params) do
          {:ok, _donation} ->
            send_resp(conn, 202, "")

          {:error, changeset} ->
            Logger.error("Failed to create donation record: #{inspect(changeset.errors)} payload=#{inspect(conn.body_params)}")

            send_resp(conn, 202, "")
        end

      {:ok, %DonationRefunded{} = event} ->
        case handle_donation_refund(event) do
          {:ok, _donation} ->
            send_resp(conn, 202, "")

          {:error, reason} ->
            Logger.error("Failed to handle refund: #{inspect(reason)} payload=#{inspect(conn.body_params)}")
            send_resp(conn, 202, "")
        end

      {:error, :invalid_payload} ->
        Logger.warning("Invalid BuyMeACoffee webhook payload: #{inspect(conn.body_params)}")
        send_resp(conn, 400, "Invalid payload")

      {:error, :unknown_event_type} ->
        Logger.error("Unknown BuyMeACoffee event type: #{event_type}")
        send_resp(conn, 202, "")
    end
  end

  defp handle_event(%{"type" => "donation.created"} = payload) do
    DonationCreated.parse(payload)
  end

  defp handle_event(%{"type" => "donation.refunded"} = payload) do
    DonationRefunded.parse(payload)
  end

  defp handle_event(%{"type" => _unknown_type}), do: {:error, :unknown_event_type}

  defp handle_event(_), do: {:error, :invalid_payload}

  defp create_donation_record(%DonationCreated{data: data}, raw_payload) do
    # Convert Unix timestamp to DateTime
    created_at = DateTime.from_unix!(data.created_at)

    Donations.create_donation(%{
      amount: Decimal.new(data.amount),
      currency: data.currency,
      provider: :buymeacoffee,
      status: :created,
      external_id: data.transaction_id,
      donor_name: data.supporter_name,
      payload: raw_payload,
      created_at: created_at
    })
  end

  defp handle_donation_refund(%DonationRefunded{data: data}) do
    # Find the donation by external_id
    case Donations.all_donations(external_id: data.transaction_id) do
      [donation] ->
        Donations.revoke_donation(donation)

      [] ->
        Logger.warning("Refund received for unknown donation: transaction_id=#{data.transaction_id}")

        {:error, :donation_not_found}

      _multiple ->
        Logger.error("Multiple donations found for transaction_id=#{data.transaction_id}")

        {:error, :multiple_donations_found}
    end
  end
end
