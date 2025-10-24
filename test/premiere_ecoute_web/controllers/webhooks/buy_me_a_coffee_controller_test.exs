defmodule PremiereEcouteWeb.Webhooks.BuyMeACoffeeControllerTest do
  use PremiereEcouteWeb.ConnCase

  import ExUnit.CaptureLog

  describe "POST /webhooks/buymeacoffee" do
    test "handles donation.created event", %{conn: conn} do
      payload = %{
        "type" => "donation.created",
        "live_mode" => false,
        "attempt" => 1,
        "created" => 1_761_213_479,
        "event_id" => 1,
        "data" => %{
          "id" => 58,
          "amount" => 5,
          "object" => "payment",
          "status" => "succeeded",
          "message" => "John bought you a coffee",
          "currency" => "USD",
          "refunded" => "false",
          "created_at" => 1_676_544_557,
          "note_hidden" => "true",
          "refunded_at" => nil,
          "support_note" => "Thanks for the good work",
          "support_type" => "Supporter",
          "supporter_name" => "John",
          "supporter_name_type" => "default",
          "transaction_id" => "pi_3Mc51bJEtINljGAa0zVykgUE",
          "application_fee" => "0.25",
          "supporter_id" => 2345,
          "supporter_email" => "john@example.com",
          "total_amount_charged" => "5.45",
          "coffee_count" => 1,
          "coffee_price" => 5
        }
      }

      log =
        capture_log(fn ->
          response =
            conn
            |> put_req_header("content-type", "application/json")
            |> post(~p"/webhooks/buymeacoffee", Jason.encode!(payload))

          assert response.status == 202
        end)

      assert log =~ "BuyMeACoffee donation created"
      assert log =~ "id=58"
      assert log =~ "supporter=John"
      assert log =~ "amount=5 USD"
      assert log =~ "coffees=1"
      assert log =~ "transaction=pi_3Mc51bJEtINljGAa0zVykgUE"
    end

    test "handles donation.refunded event", %{conn: conn} do
      payload = %{
        "type" => "donation.refunded",
        "live_mode" => false,
        "attempt" => 1,
        "created" => 1_761_213_554,
        "event_id" => 1,
        "data" => %{
          "id" => 58,
          "amount" => 5,
          "object" => "payment",
          "status" => "refunded",
          "message" => "John bought you a coffee",
          "currency" => "USD",
          "refunded" => "true",
          "created_at" => 1_676_544_557,
          "note_hidden" => "true",
          "refunded_at" => 1_676_545_041,
          "support_note" => "Thanks for the good work",
          "support_type" => "Supporter",
          "supporter_name" => "John",
          "supporter_name_type" => "default",
          "transaction_id" => "pi_3Mc51bJEtINljGAa0zVykgUE",
          "application_fee" => "0.25",
          "supporter_id" => 2345,
          "supporter_email" => "john@example.com",
          "total_amount_charged" => "5.45",
          "coffee_count" => 1,
          "coffee_price" => 5
        }
      }

      log =
        capture_log(fn ->
          response =
            conn
            |> put_req_header("content-type", "application/json")
            |> post(~p"/webhooks/buymeacoffee", Jason.encode!(payload))

          assert response.status == 202
        end)

      assert log =~ "BuyMeACoffee donation refunded"
      assert log =~ "id=58"
      assert log =~ "supporter=John"
      assert log =~ "amount=5 USD"
      assert log =~ "transaction=pi_3Mc51bJEtINljGAa0zVykgUE"
      assert log =~ "refunded_at=1676545041"
    end

    test "handles unknown event type gracefully", %{conn: conn} do
      payload = %{
        "type" => "some.unknown.event",
        "data" => %{"foo" => "bar"}
      }

      log =
        capture_log(fn ->
          response =
            conn
            |> put_req_header("content-type", "application/json")
            |> post(~p"/webhooks/buymeacoffee", Jason.encode!(payload))

          assert response.status == 202
        end)

      assert log =~ "Unknown BuyMeACoffee event type: some.unknown.event"
    end

    test "rejects invalid payload", %{conn: conn} do
      payload = %{"invalid" => "payload"}

      log =
        capture_log(fn ->
          response =
            conn
            |> put_req_header("content-type", "application/json")
            |> post(~p"/webhooks/buymeacoffee", Jason.encode!(payload))

          assert response.status == 400
        end)

      assert log =~ "Invalid BuyMeACoffee webhook payload"
    end
  end
end
