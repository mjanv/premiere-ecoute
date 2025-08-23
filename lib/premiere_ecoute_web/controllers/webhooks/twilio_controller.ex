defmodule PremiereEcouteWeb.Webhooks.TwilioController do
  use PremiereEcouteWeb, :controller

  require Logger

  alias PremiereEcoute.Events.Phone.SmsMessageSent

  def handle(conn, params) do
    case handle(params) do
      %SmsMessageSent{} -> :ok
      _ -> :ok
    end

    document =
      XmlBuilder.document(
        :Response,
        %{},
        [XmlBuilder.element(:Message, "Thanks for your message!")]
      )

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, XmlBuilder.generate(document))
  end

  def handle(%{"From" => from, "FromCountry" => country, "Body" => message}) do
    %SmsMessageSent{from: from, country: country, message: message}
  end

  def handle(_), do: nil
end
