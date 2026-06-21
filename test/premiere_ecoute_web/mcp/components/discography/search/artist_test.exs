defmodule PremiereEcouteWeb.Mcp.Components.Discography.Search.ArtistTest do
  use PremiereEcoute.DataCase, async: true

  alias Hermes.Server.Frame
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcouteWeb.Mcp.Components.Discography.Search.Artist, as: ArtistSearch

  test "finds artist by partial name match" do
    {:ok, _} = Artist.create_if_not_exists(%{name: "Miles Davis"})

    assert {:reply, resp, _} = ArtistSearch.execute(%{name: "Miles"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"artists" => artists}} = Jason.decode(json)
    assert Enum.any?(artists, &(&1["name"] == "Miles Davis"))
  end

  test "search is case-insensitive" do
    {:ok, _} = Artist.create_if_not_exists(%{name: "Daft Punk"})

    assert {:reply, resp, _} = ArtistSearch.execute(%{name: "daft"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"artists" => artists}} = Jason.decode(json)
    assert Enum.any?(artists, &(&1["name"] == "Daft Punk"))
  end

  test "returns empty list when no matches" do
    assert {:reply, resp, _} = ArtistSearch.execute(%{name: "zzznomatch"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"artists" => []}} = Jason.decode(json)
  end

  test "response includes id, name, slug" do
    {:ok, _} = Artist.create_if_not_exists(%{name: "Fields Artist Check"})

    assert {:reply, resp, _} = ArtistSearch.execute(%{name: "Fields Artist Check"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"artists" => [entry]}} = Jason.decode(json)

    assert Map.has_key?(entry, "id")
    assert Map.has_key?(entry, "name")
    assert Map.has_key?(entry, "slug")
  end
end
