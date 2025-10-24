defmodule PremiereEcoute.Apis.BuyMeACoffeeApiTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.BuyMeACoffeeApi
  alias PremiereEcoute.Events.BuyMeACoffee.Donation

  setup do
    Application.put_env(:premiere_ecoute, :buymeacoffee_api_key, "test_api_key")

    :ok
  end

  describe "get_supporters/0" do
    test "can get the list of one-time supporters" do
      ApiMock.expect(
        BuyMeACoffeeApi,
        path: {:get, "/v1/supporters"},
        headers: [
          {"authorization", "Bearer test_api_key"},
          {"content-type", "application/json"}
        ],
        response: "buy_me_a_coffee_api/supporters.json",
        status: 200
      )

      {:ok, supporters} = BuyMeACoffeeApi.get_supporters()

      assert length(supporters) == 2

      assert [
               %Donation{
                 support_id: 63_434,
                 supporter_name: "John",
                 support_note: "Thanks for the good work",
                 support_coffees: 5,
                 transaction_id: "ch_aRiE56dJk",
                 support_visibility: 1,
                 support_created_on: "2020-03-08 20:38:00",
                 support_updated_on: "2020-03-08 20:38:00",
                 transfer_id: nil,
                 support_note_id: 64_335,
                 supporter_id: nil,
                 supporter_email: nil,
                 payment_id: 32_452
               },
               %Donation{
                 support_id: 63_431,
                 supporter_name: "Jane Doe",
                 support_note: "Keep it up!",
                 support_coffees: 3,
                 transaction_id: "ch_bTjF67eKl",
                 support_visibility: 1,
                 support_created_on: "2020-03-07 15:22:00",
                 support_updated_on: "2020-03-07 15:22:00",
                 transfer_id: nil,
                 support_note_id: 64_332,
                 supporter_id: 1234,
                 supporter_email: "jane@example.com",
                 payment_id: 32_449
               }
             ] = supporters
    end

    test "returns empty list when no supporters" do
      ApiMock.expect(
        BuyMeACoffeeApi,
        path: {:get, "/v1/supporters"},
        headers: [
          {"authorization", "Bearer test_api_key"},
          {"content-type", "application/json"}
        ],
        response: %{"data" => []},
        status: 200
      )

      {:ok, supporters} = BuyMeACoffeeApi.get_supporters()

      assert supporters == []
    end
  end
end
