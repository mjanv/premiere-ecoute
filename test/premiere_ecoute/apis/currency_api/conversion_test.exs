defmodule PremiereEcoute.Apis.CurrencyApi.ConversionTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.CurrencyApi

  describe "convert/1" do
    test "can convert USD to EUR with specified amount" do
      ApiMock.expect(
        CurrencyApi,
        path: {:get, "/latest"},
        params: %{from: "USD", to: "EUR", amount: 100},
        response: "currency_api/conversion/usd_to_eur.json",
        status: 200
      )

      {:ok, response} = CurrencyApi.Conversion.convert(%{amount: 100, currency: "USD"})

      assert %{
               amount: 92.5,
               currency: "EUR"
             } = response
    end

    test "can convert GBP to EUR with specified amount" do
      ApiMock.expect(
        CurrencyApi,
        path: {:get, "/latest"},
        params: %{from: "GBP", to: "EUR", amount: 50},
        response: "currency_api/conversion/gbp_to_eur.json",
        status: 200
      )

      {:ok, response} = CurrencyApi.Conversion.convert(%{amount: 50, currency: "GBP"})

      assert %{
               amount: 59.75,
               currency: "EUR"
             } = response
    end

    test "can convert with lowercase currency code" do
      ApiMock.expect(
        CurrencyApi,
        path: {:get, "/latest"},
        params: %{from: "USD", to: "EUR", amount: 100},
        response: "currency_api/conversion/usd_to_eur.json",
        status: 200
      )

      {:ok, response} = CurrencyApi.Conversion.convert(%{amount: 100, currency: "usd"})

      assert %{
               amount: 92.5,
               currency: "EUR"
             } = response
    end

    test "can convert with decimal amount" do
      ApiMock.expect(
        CurrencyApi,
        path: {:get, "/latest"},
        params: %{from: "USD", to: "EUR", amount: 25.50},
        response: %{
          "amount" => 25.50,
          "base" => "USD",
          "date" => "2025-10-23",
          "rates" => %{"EUR" => 23.5875}
        },
        status: 200
      )

      {:ok, response} = CurrencyApi.Conversion.convert(%{amount: 25.50, currency: "USD"})

      assert %{
               amount: 23.5875,
               currency: "EUR"
             } = response
    end

    test "returns error when API returns non-200 status" do
      ApiMock.expect(
        CurrencyApi,
        path: {:get, "/latest"},
        params: %{from: "INVALID", to: "EUR", amount: 100},
        response: %{"message" => "Invalid currency code"},
        status: 400
      )

      assert {:error, "API error: 400"} =
               CurrencyApi.Conversion.convert(%{amount: 100, currency: "INVALID"})
    end

    test "returns error when response format is unexpected" do
      ApiMock.expect(
        CurrencyApi,
        path: {:get, "/latest"},
        params: %{from: "USD", to: "EUR", amount: 100},
        response: %{"unexpected" => "format"},
        status: 200
      )

      assert {:error, "API error: 200"} =
               CurrencyApi.Conversion.convert(%{amount: 100, currency: "USD"})
    end

    test "returns error when EUR rate is missing from response" do
      ApiMock.expect(
        CurrencyApi,
        path: {:get, "/latest"},
        params: %{from: "USD", to: "EUR", amount: 100},
        response: %{
          "amount" => 100,
          "base" => "USD",
          "date" => "2025-10-23",
          "rates" => %{"GBP" => 75.0}
        },
        status: 200
      )

      assert {:error, "API error: 200"} =
               CurrencyApi.Conversion.convert(%{amount: 100, currency: "USD"})
    end
  end
end
