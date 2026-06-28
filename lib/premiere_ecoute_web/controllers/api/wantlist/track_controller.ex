defmodule PremiereEcouteWeb.Api.Wantlist.TrackController do
  @moduledoc """
  API controller for saving the currently playing track to the authenticated user's wantlist.
  """

  use PremiereEcouteWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Wantlists
  alias PremiereEcouteWeb.Schemas

  operation(:create,
    summary: "Save current track",
    description: "Saves the track currently playing on the broadcaster's stream to the authenticated user's wantlist.",
    tags: ["Wantlist"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer", "viewer"],
    parameters: [
      broadcaster_id: [in: :query, description: "Twitch user ID of the broadcaster", type: :string, required: true]
    ],
    responses: [
      ok: {"Track saved", "application/json", Schemas.OkResponse},
      bad_request: "Missing broadcaster_id parameter",
      not_found: "Broadcaster not found or no track currently playing",
      unprocessable_entity: "Track could not be saved",
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(%{assigns: %{current_scope: %{user: user}}} = conn, %{"broadcaster_id" => broadcaster_twitch_id}) do
    with %User{} = broadcaster <- Accounts.get_user_by_twitch_id(broadcaster_twitch_id),
         {:playback, {:ok, playback}} <-
           {:playback, Apis.cache(:spotify).get_playback_state(Scope.for_user(broadcaster), PlaybackState.default())},
         {:ok, spotify_id} <- current_track_id(playback),
         {:ok, _item} <- Wantlists.impl().add_radio_track(user.id, spotify_id) do
      conn
      |> put_status(:ok)
      |> json(%{ok: true})
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "Broadcaster not found"})
      :no_track -> conn |> put_status(:not_found) |> json(%{error: "No track currently playing"})
      {:playback, {:error, _}} -> conn |> put_status(:not_found) |> json(%{error: "No track currently playing"})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Track could not be saved"})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: broadcaster_id"})
  end

  defp current_track_id(%PlaybackState{item: %{uri: "spotify:track:" <> id}}), do: {:ok, id}
  defp current_track_id(_), do: :no_track
end
