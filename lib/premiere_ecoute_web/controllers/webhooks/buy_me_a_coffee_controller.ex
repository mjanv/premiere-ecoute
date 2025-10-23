defmodule PremiereEcouteWeb.Webhooks.BuyMeACoffeeController do
  use PremiereEcouteWeb, :controller

  require Logger

  alias PremiereEcoute.BuyMeACoffee.DonationCreated
  alias PremiereEcoute.BuyMeACoffee.DonationRefunded
  alias PremiereEcoute.Telemetry.ApiMetrics

  # AIDEV-NOTE: Webhook controller for BuyMeACoffee donation events; no HMAC validation yet
  def handle(conn, _params) do
    event_type = get_in(conn.body_params, ["type"])
    ApiMetrics.webhook_event(:buymeacoffee, event_type)

    case handle(conn.body_params) do
      {:ok, %DonationCreated{} = event} ->
        log_donation_created(event)
        send_resp(conn, 202, "")

      {:ok, %DonationRefunded{} = event} ->
        log_donation_refunded(event)
        send_resp(conn, 202, "")

      {:error, :invalid_payload} ->
        Logger.warning("Invalid BuyMeACoffee webhook payload: #{inspect(conn.body_params)}")
        send_resp(conn, 400, "Invalid payload")

      {:error, :unknown_event_type} ->
        Logger.info("Unknown BuyMeACoffee event type: #{event_type}")
        send_resp(conn, 202, "")
    end
  end

  defp handle(%{"type" => "donation.created"} = payload) do
    DonationCreated.parse(payload)
  end

  defp handle(%{"type" => "donation.refunded"} = payload) do
    DonationRefunded.parse(payload)
  end

  defp handle(%{"type" => _unknown_type}), do: {:error, :unknown_event_type}

  defp handle(_), do: {:error, :invalid_payload}

  defp log_donation_created(%DonationCreated{data: data}) do
    Logger.info(
      "BuyMeACoffee donation created: " <>
        "id=#{data.id} " <>
        "supporter=#{data.supporter_name} " <>
        "amount=#{data.amount} #{data.currency} " <>
        "coffees=#{data.coffee_count} " <>
        "transaction=#{data.transaction_id}"
    )
  end

  defp log_donation_refunded(%DonationRefunded{data: data}) do
    Logger.warning(
      "BuyMeACoffee donation refunded: " <>
        "id=#{data.id} " <>
        "supporter=#{data.supporter_name} " <>
        "amount=#{data.amount} #{data.currency} " <>
        "transaction=#{data.transaction_id} " <>
        "refunded_at=#{data.refunded_at}"
    )
  end
end
