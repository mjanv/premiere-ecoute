defmodule PremiereEcoute.MailerTest do
  use PremiereEcoute.DataCase

  import Swoosh.TestAssertions

  alias PremiereEcoute.Events.AccountCreated
  alias PremiereEcoute.Mailer

  describe "dispatch/1" do
    test "send an email from an event" do
      event = %AccountCreated{id: UUID.uuid4(), twitch_user_id: "user_id"}

      Mailer.dispatch(event)

      assert_email_sent(
        to: {"Maxime Janvier", "maxime.janvier@gmail.com"},
        from: {"Premiere Ecoute", "hello@premiere-ecoute.fr"},
        subject: "AccountCreated",
        text_body: to_string(event)
      )
    end
  end
end
