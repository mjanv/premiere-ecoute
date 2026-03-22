defmodule PremiereEcouteWeb.Api.VoteController do
  @moduledoc """
  API controller for submitting track votes.

  Streamers vote on their own session. Viewers must supply a `username` body param
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
    summary: "Vote on current track",
    description: "Submits a rating (0–10) for the current track in the session.",
    tags: ["Session"],
    security: [%{"bearer" => []}],
    request_body:
      {"Vote payload", "application/json",
       %Schema{
         type: :object,
         required: [:rating],
         properties: %{
           rating: %Schema{type: :integer, minimum: 0, maximum: 10},
           username: %Schema{type: :string, description: "Broadcaster username (required for viewers)"}
         }
       }, required: true},
    responses: [
      ok:
        {"Vote accepted", "application/json",
         %Schema{
           type: :object,
           properties: %{
             ok: %Schema{type: :boolean, example: true},
             rating: %Schema{type: :integer}
           }
         }},
      not_found: {"Broadcaster not found", "application/json", @error_response},
      unprocessable_entity: {"Invalid rating", "application/json", @error_response},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @doc """
  Submits a vote for the current track (0–10).
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(%{assigns: %{current_scope: %{user: %{role: :streamer, twitch: %{user_id: user_id}}}}} = conn, %{"rating" => rating})
      when rating in 0..10 do
    Sessions.impl().publish_message(%MessageSent{
      broadcaster_id: user_id,
      user_id: user_id,
      message: to_string(rating),
      is_streamer: true
    })

    json(conn, %{ok: true, rating: rating})
  end

  def create(%{assigns: %{current_scope: %{user: %{role: :viewer} = caller}}} = conn, %{
        "rating" => rating,
        "username" => username
      })
      when rating in 0..10 do
    case Accounts.get_user_by_username(username) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Broadcaster not found"})

      broadcaster ->
        Sessions.impl().publish_message(%MessageSent{
          broadcaster_id: broadcaster.twitch.user_id,
          user_id: caller.twitch.user_id,
          message: to_string(rating),
          is_streamer: false
        })

        json(conn, %{ok: true, rating: rating})
    end
  end

  def create(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "rating must be an integer between 0 and 10"})
  end
end
