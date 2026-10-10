defmodule PremiereEcoute.Accounts.StreamerSignupEmailTest do
  use PremiereEcoute.DataCase, async: false

  import Swoosh.TestAssertions

  alias PremiereEcoute.Accounts.Mailer
  alias PremiereEcoute.Accounts.Notifier
  alias PremiereEcoute.Events.AccountCreated

  setup do
    mailer = Application.get_env(:premiere_ecoute, :mailer)
    Application.put_env(:premiere_ecoute, :mailer, Mailer)
    on_exit(fn -> Application.put_env(:premiere_ecoute, :mailer, mailer) end)
  end

  describe "Notifier.handle/1 on AccountCreated" do
    test "emails the creation of a streamer account" do
      streamer = user_fixture(%{role: :streamer})

      Notifier.handle(%EventStore.RecordedEvent{data: %AccountCreated{id: streamer.id}})

      assert_email_sent(subject: "New streamer: #{streamer.username}")
    end

    test "sends nothing for a viewer account" do
      viewer = user_fixture(%{role: :viewer})

      Notifier.handle(%EventStore.RecordedEvent{data: %AccountCreated{id: viewer.id}})

      refute_email_sent()
    end
  end

  describe "Mailer.dispatch/1 on AccountCreated" do
    test "sends a readable email for a streamer account" do
      streamer = user_fixture(%{role: :streamer})

      Mailer.dispatch(%AccountCreated{id: streamer.id})

      assert_email_sent(
        to: {"Maxime Janvier", "maxime.janvier@gmail.com"},
        from: {"Premiere Ecoute", "hello@premiere-ecoute.fr"},
        subject: "New streamer: #{streamer.username}"
      )
    end
  end
end
