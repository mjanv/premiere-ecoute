defmodule PremiereEcouteWeb.Mcp.Components.ProfileTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.AccountsFixtures

  alias Hermes.Server.Frame
  alias PremiereEcouteWeb.Mcp.Components.Profile

  defp authenticated_frame(user) do
    Frame.assign(%Frame{}, :current_user, user)
  end

  test "returns account info for the authenticated user" do
    user = user_fixture()
    frame = authenticated_frame(user)

    assert {:reply, resp, ^frame} = Profile.read(%{}, frame)
    assert %Hermes.Server.Response{type: :resource, contents: %{"text" => json}} = resp

    assert {:ok, data} = Jason.decode(json)
    assert data["id"] == user.id
    assert data["email"] == user.email
    assert data["username"] == user.username
    assert data["role"] == to_string(user.role)
  end

  test "includes profile embed" do
    user = user_fixture()
    frame = authenticated_frame(user)

    assert {:reply, resp, ^frame} = Profile.read(%{}, frame)
    assert %Hermes.Server.Response{contents: %{"text" => json}} = resp
    assert {:ok, %{"profile" => profile}} = Jason.decode(json)
    assert is_map(profile)
    assert Map.has_key?(profile, "language")
    assert Map.has_key?(profile, "color_scheme")
    assert Map.has_key?(profile, "timezone")
  end
end
