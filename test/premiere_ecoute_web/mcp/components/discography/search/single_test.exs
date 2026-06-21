defmodule PremiereEcouteWeb.Mcp.Components.Discography.Search.SingleTest do
  use PremiereEcoute.DataCase, async: true

  alias Hermes.Server.Frame
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Discography.SingleArtist
  alias PremiereEcouteWeb.Mcp.Components.Discography.Search.Single, as: SingleSearch

  test "finds single by partial name match" do
    {:ok, single} = Single.create_if_not_exists(single_fixture(%{name: "Feel Good Inc."}))

    assert {:reply, resp, _} = SingleSearch.execute(%{name: "Feel Good"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"singles" => singles}} = Jason.decode(json)
    assert Enum.any?(singles, &(&1["name"] == single.name))
  end

  test "finds single by partial artist name" do
    {:ok, single} = Single.create_if_not_exists(single_fixture(%{name: "Unique Single XYZ"}))
    {:ok, artist} = Artist.create_if_not_exists(%{name: "Unique Fuzzy Band"})
    Repo.insert!(%SingleArtist{single_id: single.id, artist_id: artist.id})

    assert {:reply, resp, _} = SingleSearch.execute(%{name: "Unique Fuzzy"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"singles" => singles}} = Jason.decode(json)
    assert Enum.any?(singles, &(&1["name"] == "Unique Single XYZ"))
  end

  test "search is case-insensitive" do
    {:ok, _} = Single.create_if_not_exists(single_fixture(%{name: "Blue In Green"}))

    assert {:reply, resp, _} = SingleSearch.execute(%{name: "blue in"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"singles" => singles}} = Jason.decode(json)
    assert Enum.any?(singles, &(&1["name"] == "Blue In Green"))
  end

  test "returns empty list when no matches" do
    assert {:reply, resp, _} = SingleSearch.execute(%{name: "zzznomatch"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"singles" => []}} = Jason.decode(json)
  end

  test "response includes id, name, slug, cover_url, artist" do
    {:ok, _} = Single.create_if_not_exists(single_fixture(%{name: "Fields Single Check"}))

    assert {:reply, resp, _} = SingleSearch.execute(%{name: "Fields Single Check"}, %Frame{})
    assert %Hermes.Server.Response{content: [%{"text" => json}]} = resp
    assert {:ok, %{"singles" => [entry]}} = Jason.decode(json)

    assert Map.has_key?(entry, "id")
    assert Map.has_key?(entry, "name")
    assert Map.has_key?(entry, "slug")
    assert Map.has_key?(entry, "cover_url")
    assert Map.has_key?(entry, "artist")
  end
end
