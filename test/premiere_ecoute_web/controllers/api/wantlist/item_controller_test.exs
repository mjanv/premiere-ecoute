defmodule PremiereEcouteWeb.Api.Wantlist.ItemControllerTest do
  use PremiereEcouteWeb.ApiCase, async: false

  alias PremiereEcouteWeb.Api.Wantlist.ItemController

  setup_mock(PremiereEcoute.Wantlists)

  describe "DELETE /api/wantlist/items/:id" do
    test "removes the item from the wantlist", %{conn: conn} do
      user = user_fixture()

      expect(PremiereEcoute.Wantlists.Mock, :remove_item, fn user_id, item_id ->
        assert user_id == user.id
        assert item_id == 42
        {:ok, %PremiereEcoute.Wantlists.WantlistItem{id: 42}}
      end)

      conn
      |> auth(user)
      |> delete(~p"/api/wantlist/items/42")
      |> response(200, op(ItemController, :delete))
    end

    test "returns 404 when item does not exist or is not owned", %{conn: conn} do
      user = user_fixture()

      expect(PremiereEcoute.Wantlists.Mock, :remove_item, fn _user_id, _item_id ->
        {:error, :not_found}
      end)

      conn
      |> auth(user)
      |> delete(~p"/api/wantlist/items/99")
      |> json_response(404)
    end

    test "returns 401 without authorization header", %{conn: conn} do
      conn
      |> delete(~p"/api/wantlist/items/1")
      |> json_response(401)
    end
  end
end
