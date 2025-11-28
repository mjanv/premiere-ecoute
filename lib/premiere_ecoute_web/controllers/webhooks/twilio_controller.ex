defmodule PremiereEcouteWeb.Webhooks.TwilioController do
  @moduledoc """
  Twilio SMS webhook handler controller.

  Processes incoming SMS messages from Twilio webhooks, parses message data with sender and country information, and responds with TwiML acknowledgment messages.
  """

  use PremiereEcouteWeb, :controller

  require Logger

  alias PremiereEcoute.Events.Phone.SmsMessageSent

  @doc """
  Processes Twilio SMS webhook requests and responds with TwiML.

  Parses incoming SMS message data, creates SmsMessageSent event, and responds with XML acknowledgment message using TwiML format.
  """
  @spec handle(Plug.Conn.t(), map()) :: Plug.Conn.t()
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

  @doc """
  Parses Twilio webhook parameters into SmsMessageSent event.

  Extracts sender phone number, country, and message body from Twilio webhook parameters to create application event structure.
  """
  @spec handle(map()) :: SmsMessageSent.t() | nil
  def handle(%{"From" => from, "FromCountry" => country, "Body" => message}) do
    %SmsMessageSent{from: from, country: country, message: message}
  end

  def handle(_), do: nil
end
