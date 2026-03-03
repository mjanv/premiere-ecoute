defmodule PremiereEcouteWeb.ApiCase do
  @moduledoc """
  Test case for API controllers.

  Builds on ConnCase and adds helpers for bearer authentication,
  operation ID resolution, and response validation against the OpenAPI spec.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use PremiereEcouteWeb.ConnCase

      import OpenApiSpex.TestAssertions
      import PremiereEcouteWeb.ApiCase
    end
  end

  @doc """
  Adds a Bearer token authorization header for the given user.
  """
  @spec auth(Plug.Conn.t(), PremiereEcoute.Accounts.User.t()) :: Plug.Conn.t()
  def auth(conn, user) do
    token = PremiereEcoute.Accounts.generate_user_api_token(user)
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  @doc """
  Builds the OpenAPI operation ID for an API controller action.

  Accepts either the short controller name (atom) or the full module.

  ## Examples

      op(UserProfileController, :show)
      # => "PremiereEcouteWeb.Api.UserProfileController.show"

      op(PremiereEcouteWeb.Api.UserProfileController, :show)
      # => "PremiereEcouteWeb.Api.UserProfileController.show"
  """
  @spec op(module(), atom()) :: String.t()
  def op(controller, action) do
    name = controller |> to_string() |> String.replace_prefix("Elixir.", "")

    module =
      if String.starts_with?(name, "PremiereEcouteWeb.Api."),
        do: name,
        else: "PremiereEcouteWeb.Api.#{name}"

    "#{module}.#{action}"
  end

  @doc """
  Asserts the response conforms to the OpenAPI spec for the given operation,
  then returns the decoded JSON body.

  Combines `assert_operation_response/2` and `json_response/2` into one
  pipeable call.
  """
  @spec response(Plug.Conn.t(), pos_integer(), String.t()) :: map()
  def response(conn, status, operation) do
    OpenApiSpex.TestAssertions.assert_operation_response(conn, operation)
    Phoenix.ConnTest.json_response(conn, status)
  end
end
