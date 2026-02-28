defmodule PremiereEcouteWeb.Webhooks.TwilioControllerTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias PremiereEcoute.Events.Phone.SmsMessageSent
  alias PremiereEcouteWeb.Webhooks.TwilioController

  @sms %{
    "AccountSid" => "AC1d91e20dca1857d71d3fb0c4c3012468",
    "ApiVersion" => "2010-04-01",
    "Body" => "hello!",
    "From" => "+33677234176",
    "FromCity" => "",
    "FromCountry" => "FR",
    "FromState" => "",
    "FromZip" => "",
    "MessageSid" => "SMfb8680921537b64694e2d552d2fb5d02",
    "NumMedia" => "0",
    "NumSegments" => "1",
    "SmsMessageSid" => "SMfb8680921537b64694e2d552d2fb5d02",
    "SmsSid" => "SMfb8680921537b64694e2d552d2fb5d02",
    "SmsStatus" => "received",
    "To" => "+17744834761",
    "ToCity" => "",
    "ToCountry" => "US",
    "ToState" => "MA",
    "ToZip" => ""
  }

  describe "POST /webhooks/twilio" do
    test "handles Twilio SMS", %{conn: conn} do
      payload = @sms

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/twilio", Jason.encode!(payload))

      assert response.status == 200

      assert response.resp_body ==
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Response>\n  <Message>Thanks for your message!</Message>\n</Response>"

      assert get_resp_header(response, "content-type") == ["application/xml; charset=utf-8"]
    end
  end

  describe "handle/1" do
    test "channel.chat.message" do
      event = TwilioController.handle(@sms)

      assert event == %SmsMessageSent{from: "+33677234176", country: "FR", message: "hello!"}
    end
  end
end
