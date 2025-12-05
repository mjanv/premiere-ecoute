defmodule PremiereEcoute.Twitch.History.SiteHistory.ChatMessagesTest do
  @moduledoc false

  use ExUnit.Case

  @moduletag :skip

  alias PremiereEcoute.ExplorerCase
  alias PremiereEcoute.Twitch.History.SiteHistory.ChatMessages

  @zip "priv/request-1.zip"

  test "read/2" do
    chat_messages = ChatMessages.read(@zip)

    assert ExplorerCase.equal_master?(chat_messages, "chat_messages")
  end

  test "group_month_year/1" do
    chat_messages = ChatMessages.read(@zip)
    grouped = ChatMessages.group_month_year(chat_messages)

    assert Explorer.DataFrame.shape(grouped) == {429, 4}
  end
end
