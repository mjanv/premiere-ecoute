defmodule PremiereEcouteWeb.Webhooks.BuyMeACoffeeControllerTest do
  use PremiereEcouteWeb.ConnCase

  import ExUnit.CaptureLog

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Payments.FrankfurterApi
  alias PremiereEcoute.Donations

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  describe "POST /webhooks/buymeacoffee - donation.created" do
    test "creates donation record with active goal when currencies match", %{conn: conn} do
      # Create an active goal with matching currency
      {:ok, goal} =
        Donations.create_goal(%{
          title: "Test Goal",
          target_amount: 100,
          currency: "USD",
          start_date: Date.utc_today() |> Date.add(-1),
          end_date: Date.utc_today() |> Date.add(30)
        })

      {:ok, _} = Donations.enable_goal(goal)

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

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/buymeacoffee", Jason.encode!(payload))

      assert response.status == 202

      # Verify donation was created
      donations = Donations.all_donations()
      assert length(donations) == 1
      donation = hd(donations)

      assert Decimal.equal?(donation.amount, Decimal.new(5))
      assert donation.currency == "USD"
      assert donation.provider == :buymeacoffee
      assert donation.status == :created
      assert donation.external_id == "pi_3Mc51bJEtINljGAa0zVykgUE"
      assert donation.donor_name == "John"
      assert donation.goal_id == goal.id
      assert donation.payload == payload
    end

    test "creates donation record with currency conversion when currencies don't match", %{conn: conn} do
      # Create an active goal with different currency (EUR)
      {:ok, goal} =
        Donations.create_goal(%{
          title: "Test Goal",
          target_amount: 100,
          currency: "EUR",
          start_date: Date.utc_today() |> Date.add(-1),
          end_date: Date.utc_today() |> Date.add(30)
        })

      {:ok, _} = Donations.enable_goal(goal)

      # Mock the Frankfurter API to convert USD to EUR
      ApiMock.expect(
        FrankfurterApi,
        path: {:get, "/latest"},
        params: %{"amount" => "10.0", "from" => "USD", "to" => "EUR"},
        response: %{
          "amount" => 10,
          "base" => "USD",
          "date" => "2025-10-26",
          "rates" => %{"EUR" => 9.25}
        },
        status: 200
      )

      payload = %{
        "type" => "donation.created",
        "live_mode" => false,
        "attempt" => 1,
        "created" => 1_761_213_479,
        "event_id" => 2,
        "data" => %{
          "id" => 59,
          "amount" => 10,
          "object" => "payment",
          "status" => "succeeded",
          "message" => "Jane bought you a coffee",
          "currency" => "USD",
          "refunded" => "false",
          "created_at" => 1_676_544_600,
          "note_hidden" => "true",
          "refunded_at" => nil,
          "support_note" => "Great content!",
          "support_type" => "Supporter",
          "supporter_name" => "Jane",
          "supporter_name_type" => "default",
          "transaction_id" => "pi_3Mc51bJEtINljGAa0zVykgUF",
          "application_fee" => "0.50",
          "supporter_id" => 2346,
          "supporter_email" => "jane@example.com",
          "total_amount_charged" => "10.90",
          "coffee_count" => 2,
          "coffee_price" => 5
        }
      }

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/buymeacoffee", Jason.encode!(payload))

      assert response.status == 202

      # Verify donation was created with currency conversion
      donations = Donations.all_donations()
      assert length(donations) == 1
      donation = hd(donations)

      # Amount and currency should be converted to goal's currency
      assert Decimal.equal?(donation.amount, Decimal.new("9.25"))
      assert donation.currency == "EUR"
      # Donation should be attached to the goal
      assert donation.goal_id == goal.id
      # Original payload should be preserved unchanged
      assert donation.payload == payload
    end

    test "creates donation record without goal when no active goal exists", %{conn: conn} do
      payload = %{
        "type" => "donation.created",
        "live_mode" => false,
        "attempt" => 1,
        "created" => 1_761_213_479,
        "event_id" => 3,
        "data" => %{
          "id" => 60,
          "amount" => 15,
          "object" => "payment",
          "status" => "succeeded",
          "message" => "Bob bought you a coffee",
          "currency" => "USD",
          "refunded" => "false",
          "created_at" => 1_676_544_700,
          "note_hidden" => "true",
          "refunded_at" => nil,
          "support_note" => "Keep it up!",
          "support_type" => "Supporter",
          "supporter_name" => "Bob",
          "supporter_name_type" => "default",
          "transaction_id" => "pi_3Mc51bJEtINljGAa0zVykgUG",
          "application_fee" => "0.75",
          "supporter_id" => 2347,
          "supporter_email" => "bob@example.com",
          "total_amount_charged" => "16.35",
          "coffee_count" => 3,
          "coffee_price" => 5
        }
      }

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/buymeacoffee", Jason.encode!(payload))

      assert response.status == 202

      # Verify donation was created without goal
      donations = Donations.all_donations()
      assert length(donations) == 1
      donation = hd(donations)

      assert Decimal.equal?(donation.amount, Decimal.new(15))
      assert donation.currency == "USD"
      assert donation.goal_id == nil
      assert donation.payload == payload
    end

    test "rejects duplicate donation with same external_id", %{conn: conn} do
      # Create initial donation
      {:ok, _} =
        Donations.create_donation(%{
          amount: 5,
          currency: "USD",
          external_id: "pi_3Mc51bJEtINljGAa0zVykgUE",
          created_at: DateTime.utc_now(),
          payload: %{}
        })

      payload = %{
        "type" => "donation.created",
        "live_mode" => false,
        "attempt" => 1,
        "created" => 1_761_213_479,
        "event_id" => 4,
        "data" => %{
          "id" => 61,
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

      assert log =~ "Failed to create donation record"

      # Verify only one donation exists
      donations = Donations.all_donations()
      assert length(donations) == 1
    end
  end

  describe "POST /webhooks/buymeacoffee - donation.refunded" do
    test "marks existing donation as refunded", %{conn: conn} do
      # Create a donation first
      {:ok, donation} =
        Donations.create_donation(%{
          amount: 5,
          currency: "USD",
          external_id: "pi_3Mc51bJEtINljGAa0zVykgUE",
          donor_name: "John",
          created_at: DateTime.utc_now(),
          payload: %{}
        })

      assert donation.status == :created

      payload = %{
        "type" => "donation.refunded",
        "live_mode" => false,
        "attempt" => 1,
        "created" => 1_761_213_554,
        "event_id" => 5,
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

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/buymeacoffee", Jason.encode!(payload))

      assert response.status == 202

      # Verify donation was marked as refunded
      refunded_donation = Donations.get_donation(donation.id)
      assert refunded_donation.status == :refunded
    end

    test "handles refund for non-existent donation gracefully", %{conn: conn} do
      payload = %{
        "type" => "donation.refunded",
        "live_mode" => false,
        "attempt" => 1,
        "created" => 1_761_213_554,
        "event_id" => 6,
        "data" => %{
          "id" => 99,
          "amount" => 5,
          "object" => "payment",
          "status" => "refunded",
          "message" => "Unknown donor bought you a coffee",
          "currency" => "USD",
          "refunded" => "true",
          "created_at" => 1_676_544_557,
          "note_hidden" => "true",
          "refunded_at" => 1_676_545_041,
          "support_note" => "",
          "support_type" => "Supporter",
          "supporter_name" => "Unknown",
          "supporter_name_type" => "default",
          "transaction_id" => "pi_NON_EXISTENT_TRANSACTION",
          "application_fee" => "0.25",
          "supporter_id" => 9999,
          "supporter_email" => "unknown@example.com",
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

      assert log =~ "Refund received for unknown donation"
      assert log =~ "transaction_id=pi_NON_EXISTENT_TRANSACTION"
    end
  end

  describe "POST /webhooks/buymeacoffee - error handling" do
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

          assert response.status == 400
        end)

      assert log =~ "Invalid BuyMeACoffee webhook payload"
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
