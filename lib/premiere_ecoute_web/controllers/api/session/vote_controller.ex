defmodule PremiereEcouteWeb.Api.Session.VoteController do
  @moduledoc """
  API controller for submitting track votes.

  Streamers vote on their own session. Viewers must supply a `username` body param
  (the broadcaster's username) to identify whose session to vote on.
  """

  use PremiereEcouteWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions
  alias PremiereEcouteWeb.Schemas

  operation(:create,
    summary: "Vote on current track",
    description:
      "Submits a rating (0–10) for the current track in the session. Streamers vote on their own session directly; viewers must supply a `username` body param (the broadcaster's username).",
    tags: ["Session"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer", "viewer"],
    request_body: {"Vote payload", "application/json", Schemas.SessionVoteRequest, required: true},
    responses: [
      ok: {"Vote accepted", "application/json", Schemas.SessionVoteResponse},
      not_found: {"Broadcaster not found", "application/json", Schemas.ErrorResponse},
      unprocessable_entity: {"Invalid rating", "application/json", Schemas.ErrorResponse},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @doc """
  Submits a vote for the current track (0–10).
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(%{assigns: %{current_scope: %{user: %{role: :streamer, twitch: %{user_id: user_id}}}}} = conn, %{"rating" => rating}) do
    Sessions.impl().publish_message(%MessageSent{
      broadcaster_id: user_id,
      user_id: user_id,
      message: to_string(rating),
      is_streamer: true
    })

    json(conn, %{ok: true, rating: rating})
  end

  def create(%{assigns: %{current_scope: %{user: %{role: role} = caller}}} = conn, %{
        "rating" => rating,
        "username" => username
      })
      when role in [:viewer, :admin] do
    case Accounts.get_user_by_username(username) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Viewer not found"})

      broadcaster ->
        Sessions.impl().publish_message(%MessageSent{
          broadcaster_id: broadcaster.twitch.user_id,
          user_id: caller.twitch.user_id,
          message: to_string(rating),
          is_streamer: false
        })

        conn |> put_status(:ok) |> json(%{ok: true, rating: rating})
    end
  end

  def create(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "Cannot process vote"})
  end
end
