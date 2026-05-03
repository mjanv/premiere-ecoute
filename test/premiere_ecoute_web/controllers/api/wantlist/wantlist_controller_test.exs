defmodule PremiereEcouteWeb.Api.Wantlist.WantlistControllerTest do
  use PremiereEcouteWeb.ApiCase, async: false

  alias PremiereEcouteWeb.Api.Wantlist.WantlistController

  setup_mock(PremiereEcoute.Wantlists)

  describe "GET /api/wantlist" do
    test "returns the user's wantlist", %{conn: conn} do
      user = user_fixture()

      expect(PremiereEcoute.Wantlists.Mock, :get_wantlist, fn user_id ->
        assert user_id == user.id
        %PremiereEcoute.Wantlists.Wantlist{id: 1, user_id: user.id, items: []}
      end)

      response =
        conn
        |> auth(user)
        |> get(~p"/api/wantlist")
        |> response(200, op(WantlistController, :show))

      assert response["id"] == 1
      assert response["items"] == []
    end

    test "returns 401 without authorization header", %{conn: conn} do
      conn
      |> get(~p"/api/wantlist")
      |> json_response(401)
    end
  end
end
