defmodule PremiereEcoute.Accounts.BotTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.Bot
  alias PremiereEcoute.Core.Cache

  setup do
    Cache.clear(:users)
    on_exit(fn -> Cache.clear(:users) end)

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
    Cache.put(:users, :bot, :wrong, expire: 5 * 60 * 1_000)
    bot3 = Bot.get()

    assert bot1.id == id
    assert bot2.id == id
    assert bot3 == :wrong
  end
end
