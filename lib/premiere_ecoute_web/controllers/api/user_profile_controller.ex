defmodule PremiereEcouteWeb.Api.UserProfileController do
  @moduledoc """
  API controller for reading and updating the authenticated user's profile.

  Supports full and partial updates: only the fields present in the request body
  are modified; omitted fields keep their current values.
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcoute.Accounts

  @doc """
  Returns the authenticated user's profile settings.
  """
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    profile = conn.assigns.current_scope.user.profile

    conn
    |> put_status(:ok)
    |> json(serialize_profile(profile))
  end

  @doc """
  Partially updates the authenticated user's profile settings.

  Only the fields included in the request body are changed; fields not present
  in the payload retain their existing values.
  """
  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, params) do
    user = conn.assigns.current_scope.user

    case Accounts.edit_user_profile(user, params) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(serialize_profile(updated_user.profile))

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  # AIDEV-NOTE: serialize_profile renders nested embeds as plain maps so that
  # Ecto.Enum atoms and embedded structs are JSON-safe. Nested embeds fall back
  # to default structs when nil (possible for users created before these fields existed).
  defp serialize_profile(profile) do
    widget = profile.widget_settings || %PremiereEcoute.Accounts.User.Profile.WidgetSettings{}
    radio = profile.radio_settings || %PremiereEcoute.Accounts.User.Profile.RadioSettings{}

    %{
      color_scheme: profile.color_scheme,
      language: profile.language,
      timezone: profile.timezone,
      widget_settings: %{
        color_primary: widget.color_primary,
        color_secondary: widget.color_secondary
      },
      radio_settings: %{
        enabled: radio.enabled,
        retention_days: radio.retention_days,
        visibility: radio.visibility
      }
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
