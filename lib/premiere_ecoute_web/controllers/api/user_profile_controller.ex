defmodule PremiereEcouteWeb.Api.UserProfileController do
  @moduledoc """
  API controller for reading and updating the authenticated user's profile.

  Supports full and partial updates: only the fields present in the request body
  are modified; omitted fields keep their current values.
  """

  use PremiereEcouteWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Repo

  @profile_schema %Schema{
    type: :object,
    properties: %{
      color_scheme: %Schema{type: :string, enum: ["light", "dark", "system"]},
      language: %Schema{type: :string, enum: ["en", "fr", "it"]},
      timezone: %Schema{type: :string, example: "Europe/Paris"},
      widget_settings: %Schema{
        type: :object,
        properties: %{
          color_primary: %Schema{type: :string, pattern: "^#[0-9A-Fa-f]{6}$", example: "#5b21b6"},
          color_secondary: %Schema{type: :string, pattern: "^#[0-9A-Fa-f]{6}$", example: "#be123c"}
        }
      },
      radio_settings: %Schema{
        type: :object,
        properties: %{
          enabled: %Schema{type: :boolean},
          retention_days: %Schema{type: :integer, minimum: 1},
          visibility: %Schema{type: :string, enum: ["private", "public"]}
        }
      }
    }
  }

  operation(:show,
    summary: "Get profile",
    description: "Returns the authenticated user's profile settings.",
    tags: ["Profile"],
    security: [%{"bearer" => []}],
    responses: [
      ok: {"Profile", "application/json", @profile_schema},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @doc """
  Returns the authenticated user's profile settings.
  """
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    profile = conn.assigns.current_scope.user.profile

    conn
    |> put_status(:ok)
    |> json(profile)
  end

  operation(:update,
    summary: "Update profile",
    description:
      "Partially updates the authenticated user's profile settings. Only fields present in the request body are changed.",
    tags: ["Profile"],
    security: [%{"bearer" => []}],
    request_body: {"Profile fields to update", "application/json", @profile_schema},
    responses: [
      ok: {"Updated profile", "application/json", @profile_schema},
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
  def update(conn, params) do
    user = conn.assigns.current_scope.user

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
