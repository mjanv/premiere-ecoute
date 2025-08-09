defmodule PremiereEcoute.Accounts.BotTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.Bot
  alias PremiereEcoute.Apis.TwitchApi.Mock, as: TwitchApi
  alias PremiereEcouteCore.Cache

  @email "maxime.janvier+premiereecoute@gmail.com"

  setup do
    Cache.clear(:users)
    on_exit(fn -> Cache.clear(:users) end)

    stub(TwitchApi, :renew_token, fn _ ->
      {:ok,
       %{
         access_token: "access_token",
         refresh_token: "refresh_token",
         expires_in: 3600
       }}
    end)

    :ok
  end

  test "Bot is not available if no #{@email} user account exists" do
    assert is_nil(Bot.get())
  end

  test "Bot is available if #{@email} user account exists" do
    %{id: id} = user_fixture(%{email: @email, twitch: %{refresh_token: "twitch_refresh_token"}})

    bot = Bot.get()

    assert bot.id == id
  end

  test "Bot can be read from cache" do
    %{id: id} = user_fixture(%{email: @email, twitch: %{refresh_token: "twitch_refresh_token"}})

    bot1 = Bot.get()
    bot2 = Bot.get()
    Cache.put(:users, :bot, :wrong, expire: 5 * 60 * 1_000)
    bot3 = Bot.get()

    assert bot1.id == id
    assert bot2.id == id
    assert bot3 == :wrong
  end
end
