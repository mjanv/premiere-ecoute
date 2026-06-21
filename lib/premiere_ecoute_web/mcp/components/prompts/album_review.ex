defmodule PremiereEcouteWeb.Mcp.Components.Prompts.AlbumReview do
  @moduledoc "Generates a prompt to write a review for a listened album"

  use Hermes.Server.Component, type: :prompt

  alias Hermes.Server.Response

  schema do
    field :album, :string, required: true
    field :artist, :string, required: true
  end

  @impl true
  def get_messages(%{album: album, artist: artist}, frame) do
    Response.prompt()
    |> Response.system_message(%{
      "type" => "text",
      "text" => "You are a music critic writing for a Twitch streaming community. Be warm, direct, and concise."
    })
    |> Response.user_message(%{
      "type" => "text",
      "text" => "Write a short review of the album \"#{album}\" by #{artist}."
    })
    |> then(fn response -> {:reply, response, frame} end)
  end
end
