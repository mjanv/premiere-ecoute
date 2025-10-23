defmodule PremiereEcoute.Apis.CurrencyConversionApi.ConversionTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.CurrencyConversionApi

  describe "convert/2" do
    test "can convert USD to EUR with specified amount" do
      ApiMock.expect(
        CurrencyConversionApi,
        path: {:get, "/latest"},
        params: %{from: "USD", to: "EUR", amount: 100},
        response: "currency_conversion_api/conversion/usd_to_eur.json",
        status: 200
      )

      {:ok, response} = CurrencyConversionApi.Conversion.convert("USD", 100)

      assert %{
               amount: 100.0,
               base: "USD",
               date: "2025-10-23",
               rates: %{"EUR" => 92.5}
             } = response
    end

    test "can convert GBP to EUR with specified amount" do
      ApiMock.expect(
        CurrencyConversionApi,
        path: {:get, "/latest"},
        params: %{from: "GBP", to: "EUR", amount: 50},
        response: "currency_conversion_api/conversion/gbp_to_eur.json",
        status: 200
      )

      {:ok, response} = CurrencyConversionApi.Conversion.convert("GBP", 50)

      assert %{
               amount: 50.0,
               base: "GBP",
               date: "2025-10-23",
               rates: %{"EUR" => 59.75}
             } = response
    end

    test "can convert with lowercase currency code" do
      ApiMock.expect(
        CurrencyConversionApi,
        path: {:get, "/latest"},
        params: %{from: "USD", to: "EUR", amount: 100},
        response: "currency_conversion_api/conversion/usd_to_eur.json",
        status: 200
      )

      {:ok, response} = CurrencyConversionApi.Conversion.convert("usd", 100)

      assert %{
               amount: 100.0,
               base: "USD",
               date: "2025-10-23",
               rates: %{"EUR" => 92.5}
             } = response
    end

    test "uses default amount of 1 when not specified" do
      ApiMock.expect(
        CurrencyConversionApi,
        path: {:get, "/latest"},
        params: %{from: "USD", to: "EUR", amount: 1},
        response: "currency_conversion_api/conversion/usd_latest_rate.json",
        status: 200
      )

      {:ok, response} = CurrencyConversionApi.Conversion.convert("USD")

      assert %{
               amount: 1.0,
               base: "USD",
               date: "2025-10-23",
               rates: %{"EUR" => 0.925}
             } = response
    end

    test "returns error when API returns non-200 status" do
      ApiMock.expect(
        CurrencyConversionApi,
        path: {:get, "/latest"},
        params: %{from: "INVALID", to: "EUR", amount: 100},
        response: %{"message" => "Invalid currency code"},
        status: 400
      )

      assert {:error, "API error: 400"} = CurrencyConversionApi.Conversion.convert("INVALID", 100)
    end

    test "returns error when response format is unexpected" do
      ApiMock.expect(
        CurrencyConversionApi,
        path: {:get, "/latest"},
        params: %{from: "USD", to: "EUR", amount: 100},
        response: %{"unexpected" => "format"},
        status: 200
      )

      assert {:error, "API error: 200"} = CurrencyConversionApi.Conversion.convert("USD", 100)
    end
  end

  describe "get_latest_rates/1" do
    test "can get latest exchange rate for USD to EUR" do
      ApiMock.expect(
        CurrencyConversionApi,
        path: {:get, "/latest"},
        params: %{from: "USD", to: "EUR", amount: 1},
        response: "currency_conversion_api/conversion/usd_latest_rate.json",
        status: 200
      )

      {:ok, response} = CurrencyConversionApi.Conversion.get_latest_rates("USD")

      assert %{
               amount: 1.0,
               base: "USD",
               date: "2025-10-23",
               rates: %{"EUR" => 0.925}
             } = response
    end

    test "returns error when currency code is invalid" do
      ApiMock.expect(
        CurrencyConversionApi,
        path: {:get, "/latest"},
        params: %{from: "XXX", to: "EUR", amount: 1},
        response: %{"message" => "Currency not found"},
        status: 404
      )

      assert {:error, "API error: 404"} =
               CurrencyConversionApi.Conversion.get_latest_rates("XXX")
    end
  end
end
