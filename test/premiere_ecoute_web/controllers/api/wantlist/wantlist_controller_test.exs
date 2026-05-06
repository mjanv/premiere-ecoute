defmodule PremiereEcouteWeb.Api.Wantlist.WantlistControllerTest do
  use PremiereEcouteWeb.ApiCase, async: false

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single
  alias PremiereEcouteWeb.Api.Wantlist.WantlistController

  setup_mock(PremiereEcoute.Wantlists)

  @wantlist_with_items %PremiereEcoute.Wantlists.Wantlist{
    items: [
      %PremiereEcoute.Wantlists.WantlistItem{
        type: :track,
        single: %Single{
          name: "Harder Better Faster Stronger",
          artist: %Artist{name: "Daft Punk"},
          provider_ids: %{spotify: "6NURUnCmsey9F5xm9NQYXZ"}
        }
      },
      %PremiereEcoute.Wantlists.WantlistItem{
        type: :album,
        album: %Album{
          name: "Discovery",
          artist: %Artist{name: "Daft Punk"},
          provider_ids: %{spotify: "2noRn2Aes5aoNVsU6iWThc"}
        }
      },
      %PremiereEcoute.Wantlists.WantlistItem{
        type: :artist,
        artist: %Artist{name: "Daft Punk", provider_ids: %{spotify: "4tZwfgrHOc3mvqYlEYSvVi"}}
      }
    ]
  }

  describe "GET /api/wantlist" do
    test "returns an empty wantlist", %{conn: conn} do
      user = user_fixture()

      expect(PremiereEcoute.Wantlists.Mock, :get_wantlist, fn user_id ->
        assert user_id == user.id
        %PremiereEcoute.Wantlists.Wantlist{user_id: user.id, items: []}
      end)

      response =
        conn
        |> auth(user)
        |> get(~p"/api/wantlist")
        |> response(200, op(WantlistController, :show))

      assert response["items"] == []
    end

    test "returns items with name, artist and provider ids", %{conn: conn} do
      user = user_fixture()
      stub(PremiereEcoute.Wantlists.Mock, :get_wantlist, fn _ -> @wantlist_with_items end)

      response =
        conn
        |> auth(user)
        |> get(~p"/api/wantlist")
        |> response(200, op(WantlistController, :show))

      assert [track, album, artist] = response["items"]

      assert track["type"] == "track"
      assert track["name"] == "Harder Better Faster Stronger"
      assert track["artist"] == "Daft Punk"
      assert track["provider_ids"]["spotify"] == "6NURUnCmsey9F5xm9NQYXZ"
      refute Map.has_key?(track, "cover_url")
      refute Map.has_key?(track, "inserted_at")

      assert album["type"] == "album"
      assert album["name"] == "Discovery"
      assert album["provider_ids"]["spotify"] == "2noRn2Aes5aoNVsU6iWThc"

      assert artist["type"] == "artist"
      assert artist["name"] == "Daft Punk"
      assert artist["provider_ids"]["spotify"] == "4tZwfgrHOc3mvqYlEYSvVi"
    end

    test "filters items by type", %{conn: conn} do
      user = user_fixture()
      stub(PremiereEcoute.Wantlists.Mock, :get_wantlist, fn _ -> @wantlist_with_items end)

      response =
        conn
        |> auth(user)
        |> get(~p"/api/wantlist?type=album")
        |> response(200, op(WantlistController, :show))

      assert [item] = response["items"]
      assert item["type"] == "album"
      assert item["name"] == "Discovery"
    end

    test "returns 401 without authorization header", %{conn: conn} do
      conn
      |> get(~p"/api/wantlist")
      |> json_response(401)
    end
  end
end
