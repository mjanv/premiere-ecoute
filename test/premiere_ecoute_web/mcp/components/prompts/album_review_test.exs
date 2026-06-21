defmodule PremiereEcouteWeb.Mcp.Components.Prompts.AlbumReviewTest do
  use ExUnit.Case, async: true

  alias Hermes.Server.Frame
  alias PremiereEcouteWeb.Mcp.Components.Prompts.AlbumReview

  test "generates a review prompt with album and artist" do
    frame = %Frame{}

    assert {:reply, resp, ^frame} = AlbumReview.get_messages(%{album: "BUBBA", artist: "Kaytranada"}, frame)
    assert %Hermes.Server.Response{type: :prompt, messages: [system, user]} = resp
    assert system["role"] == "system"
    assert user["role"] == "user"
    assert user["content"]["text"] =~ "BUBBA"
    assert user["content"]["text"] =~ "Kaytranada"
  end
end
