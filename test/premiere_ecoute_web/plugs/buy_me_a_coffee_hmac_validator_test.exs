defmodule PremiereEcouteWeb.Plugs.BuyMeACoffeeHmacValidatorTest do
  use ExUnit.Case, async: false

  alias PremiereEcouteWeb.Plugs.BuyMeACoffeeHmacValidator

  @secret "s3cre77890ab"
  @body ~s({"type":"donation.created","data":{}})

  describe "hmac/3" do
    test "accepts a body signed with the right secret" do
      signature = BuyMeACoffeeHmacValidator.signature(@secret, @body)
      headers = [{"x-signature-sha256", signature}]

      assert BuyMeACoffeeHmacValidator.hmac(headers, @secret, @body) == true
    end

    test "refuses a body signed with the wrong secret" do
      signature = BuyMeACoffeeHmacValidator.signature("wrong-secret", @body)
      headers = [{"x-signature-sha256", signature}]

      assert BuyMeACoffeeHmacValidator.hmac(headers, @secret, @body) == false
    end

    test "refuses a tampered body" do
      signature = BuyMeACoffeeHmacValidator.signature(@secret, @body)
      headers = [{"x-signature-sha256", signature}]

      assert BuyMeACoffeeHmacValidator.hmac(headers, @secret, ~s({"type":"donation.created","data":{"amount":"999"}})) ==
               false
    end

    test "refuses a request with no signature header" do
      assert BuyMeACoffeeHmacValidator.hmac([], @secret, @body) == false
    end
  end
end
