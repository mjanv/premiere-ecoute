defmodule PremiereEcoute.Accounts.BotTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.Bot

  setup do
    on_exit(fn -> :persistent_term.erase(:bot) end)

    :ok
  end

  test "Bot is not available if no premiereecoutebot@twitch.tv user account exists" do
    assert is_nil(Bot.get())
  end

  test "Bot is available if premiereecoutebot@twitch.tv user account exists" do
    %{id: id} = user_fixture(%{email: "premiereecoutebot@twitch.tv"})

    bot = Bot.get()

    assert bot.id == id
  end

  test "Bot can be read from cache" do
    %{id: id} = user_fixture(%{email: "premiereecoutebot@twitch.tv"})

    bot1 = Bot.get()
    bot2 = Bot.get()
    :persistent_term.put(:bot, :wrong)
    bot3 = Bot.get()

    assert bot1.id == id
    assert bot2.id == id
    assert bot3 == :wrong
  end
end
