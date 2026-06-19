defmodule PremiereEcouteWeb.Api.User.ProfileController do
  @moduledoc """
  API controller for reading and updating the authenticated user's profile.

  Supports full and partial updates: only the fields present in the request body
  are modified; omitted fields keep their current values.
  """

  use PremiereEcouteWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Repo
  alias PremiereEcouteWeb.Schemas

  operation(:show,
    summary: "Get profile",
    description: "Returns the authenticated user's profile settings.",
    tags: ["Profile"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer", "viewer"],
    responses: [
      ok: {"Profile", "application/json", Schemas.Profile},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @doc """
  Returns the authenticated user's profile settings.
  """
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(%{assigns: %{current_scope: %{user: user}}} = conn, _params) do
    conn
    |> put_status(:ok)
    |> json(user.profile)
  end

  operation(:update,
    summary: "Update profile",
    description:
      "Partially updates the authenticated user's profile settings. Only fields present in the request body are changed.",
    tags: ["Profile"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer", "viewer"],
    request_body: {"Profile fields to update", "application/json", Schemas.Profile},
    responses: [
      ok: {"Updated profile", "application/json", Schemas.Profile},
      unprocessable_entity: "Validation errors",
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @doc """
  Partially updates the authenticated user's profile settings.

  Only the fields included in the request body are changed; fields not present
  in the payload retain their existing values.
  """
  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(%{assigns: %{current_scope: %{user: user}}} = conn, params) do
    case Accounts.edit_user_profile(user, params) do
      {:ok, user} ->
        conn
        |> put_status(:ok)
        |> json(user.profile)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  defp format_errors(changeset) do
    changeset
    |> Repo.traverse_errors()
    |> Map.get(:profile, %{})
  end
end
