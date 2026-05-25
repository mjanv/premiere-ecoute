defmodule PremiereEcouteWeb.Api.Collection.VoteController do
  @moduledoc """
  API controller for submitting collection session votes.

  Accepts a binary choice (1 or 2) for the active vote window.
  Streamers vote on their own session. Viewers must supply a `username` param
  (the broadcaster's username) to identify whose session to vote on.
  """

  use PremiereEcouteWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions

  @error_response %Schema{
    type: :object,
    properties: %{error: %Schema{type: :string}}
  }

  operation(:create,
    summary: "Submit collection vote",
    description:
      "Submits a binary choice (1 or 2) for the active vote window. Streamers vote on their own session; viewers must supply a `username` body param (the broadcaster's username).",
    tags: ["Collection"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer", "viewer"],
    request_body:
      {"Vote payload", "application/json",
       %Schema{
         type: :object,
         required: [:choice],
         properties: %{
           choice: %Schema{type: :integer, enum: [1, 2], description: "1 for option A, 2 for option B"},
           username: %Schema{type: :string, description: "Broadcaster username (required for viewers)"}
         }
       }, required: true},
    responses: [
      ok:
        {"Vote accepted", "application/json",
         %Schema{
           type: :object,
           properties: %{ok: %Schema{type: :boolean, example: true}}
         }},
      not_found: {"Broadcaster not found", "application/json", @error_response},
      unprocessable_entity: {"Invalid choice or missing username", "application/json", @error_response},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(
        %{assigns: %{current_scope: %{user: %{role: :streamer, twitch: %{user_id: broadcaster_id}}}}} = conn,
        %{"choice" => choice}
      )
      when choice in [1, 2] do
    Sessions.impl().publish_message(%MessageSent{
      broadcaster_id: broadcaster_id,
      user_id: broadcaster_id,
      message: to_string(choice),
      is_streamer: true
    })

    json(conn, %{ok: true})
  end

  def create(
        %{assigns: %{current_scope: %{user: %{role: role, twitch: %{user_id: user_id}}}}} = conn,
        %{"choice" => choice, "username" => username}
      )
      when role in [:viewer, :admin] and choice in [1, 2] do
    case Accounts.get_user_by_username(username) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Broadcaster not found"})

      broadcaster ->
        Sessions.impl().publish_message(%MessageSent{
          broadcaster_id: broadcaster.twitch.user_id,
          user_id: user_id,
          message: to_string(choice),
          is_streamer: false
        })

        json(conn, %{ok: true})
    end
  end

  def create(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "Cannot process vote"})
  end
end
