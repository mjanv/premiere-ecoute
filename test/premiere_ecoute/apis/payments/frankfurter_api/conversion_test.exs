defmodule PremiereEcoute.Apis.Payments.FrankfurterApi.ConversionTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.Payments.FrankfurterApi

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  describe "convert/1" do
    test "can convert USD to EUR with specified amount" do
      ApiMock.expect(
        FrankfurterApi,
        path: {:get, "/latest"},
        params: %{"amount" => "100", "from" => "USD", "to" => "EUR"},
        response: "currency_api/conversion/usd_to_eur.json",
        status: 200
      )

      {:ok, response} = FrankfurterApi.Conversion.convert(%{amount: 100, currency: "USD"})

      assert response == %{amount: 92.5, currency: "EUR"}
    end

    test "can convert GBP to EUR with specified amount" do
      ApiMock.expect(
        FrankfurterApi,
        path: {:get, "/latest"},
        params: %{"amount" => "50", "from" => "GBP", "to" => "EUR"},
        response: "currency_api/conversion/gbp_to_eur.json",
        status: 200
      )

      {:ok, response} = FrankfurterApi.Conversion.convert(%{amount: 50, currency: "GBP"})

      assert response == %{amount: 59.75, currency: "EUR"}
    end

    test "can convert with lowercase currency code" do
      ApiMock.expect(
        FrankfurterApi,
        path: {:get, "/latest"},
        params: %{"amount" => "100", "from" => "USD", "to" => "EUR"},
        response: "currency_api/conversion/usd_to_eur.json",
        status: 200
      )

      {:ok, response} = FrankfurterApi.Conversion.convert(%{amount: 100, currency: "usd"})

      assert response == %{amount: 92.5, currency: "EUR"}
    end

    test "can convert with decimal amount" do
      ApiMock.expect(
        FrankfurterApi,
        path: {:get, "/latest"},
        params: %{"amount" => "25.5", "from" => "USD", "to" => "EUR"},
        response: %{
          "amount" => 25.50,
          "base" => "USD",
          "date" => "2025-10-23",
          "rates" => %{"EUR" => 23.5875}
        },
        status: 200
      )

      {:ok, response} = FrankfurterApi.Conversion.convert(%{amount: 25.50, currency: "USD"})

      assert response == %{amount: 23.5875, currency: "EUR"}
    end

    test "returns error when API returns non-200 status" do
      ApiMock.expect(
        FrankfurterApi,
        path: {:get, "/latest"},
        params: %{"amount" => "100", "from" => "INVALID", "to" => "EUR"},
        response: %{"message" => "Invalid currency code"},
        status: 400
      )

      {:error, reason} = FrankfurterApi.Conversion.convert(%{amount: 100, currency: "INVALID"})

      assert reason == "Frankfurter API error: 400"
    end

    test "returns error when response format is unexpected" do
      ApiMock.expect(
        FrankfurterApi,
        path: {:get, "/latest"},
        params: %{"amount" => "100", "from" => "USD", "to" => "EUR"},
        response: %{"unexpected" => "format"},
        status: 200
      )

      {:error, reason} = FrankfurterApi.Conversion.convert(%{amount: 100, currency: "USD"})

      assert reason == "Frankfurter API error: 200"
    end

    test "returns error when EUR rate is missing from response" do
      ApiMock.expect(
        FrankfurterApi,
        path: {:get, "/latest"},
        params: %{"amount" => "100", "from" => "USD", "to" => "EUR"},
        response: %{
          "amount" => 100,
          "base" => "USD",
          "date" => "2025-10-23",
          "rates" => %{"GBP" => 75.0}
        },
        status: 200
      )

      {:error, reason} = FrankfurterApi.Conversion.convert(%{amount: 100, currency: "USD"})

      assert reason == "Frankfurter API error: 200"
    end
  end
end
