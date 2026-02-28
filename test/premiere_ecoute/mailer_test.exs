defmodule PremiereEcoute.Accounts.MailerTest do
  use PremiereEcoute.DataCase, async: true

  import Swoosh.TestAssertions

  alias PremiereEcoute.Accounts.Mailer
  alias PremiereEcoute.Events.AccountCreated

  describe "dispatch/1" do
    test "send an email from an event" do
      event = %AccountCreated{id: UUID.uuid4()}

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
