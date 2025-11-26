defmodule PremiereEcouteWeb.Webhooks.BuyMeACoffeeController do
  @moduledoc """
  Buy Me a Coffee webhook handler controller.

  Processes Buy Me a Coffee webhooks for donation events, handling donation creation and refund events, persisting donation records, and tracking donation metrics.
  """

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
      {:ok, %DonationCreated{data: data}} ->
        %{
          amount: Decimal.new(data.amount),
          currency: data.currency,
          provider: :buymeacoffee,
          status: :created,
          external_id: data.transaction_id,
          donor_name: data.supporter_name,
          payload: conn.body_params,
          created_at: DateTime.from_unix!(data.created_at)
        }
        |> Donations.create_donation()
        |> case do
          {:ok, _donation} ->
            send_resp(conn, 202, "")

          {:error, changeset} ->
            Logger.error("Failed to create donation record: #{inspect(changeset.errors)} payload=#{inspect(conn.body_params)}")

            send_resp(conn, 202, "")
        end

      {:ok, %DonationRefunded{data: data}} ->
        case Donations.Donation.get_by(external_id: data.transaction_id) do
          nil ->
            Logger.warning("Refund received for unknown donation: transaction_id=#{data.transaction_id}")

            {:error, :donation_not_found}

          donation ->
            Donations.revoke_donation(donation)
        end
        |> case do
          {:ok, _donation} ->
            send_resp(conn, 202, "")

          {:error, reason} ->
            Logger.error("Failed to handle refund: #{inspect(reason)}")
            send_resp(conn, 202, "")
        end

      {:error, :invalid_payload} ->
        Logger.warning("Invalid BuyMeACoffee webhook payload: #{inspect(conn.body_params)}")
        send_resp(conn, 400, "Invalid payload")
    end
  end

  defp handle_event(%{"type" => "donation.created"} = payload) do
    DonationCreated.parse(payload)
  end

  defp handle_event(%{"type" => "donation.refunded"} = payload) do
    DonationRefunded.parse(payload)
  end

  defp handle_event(_), do: {:error, :invalid_payload}
end
