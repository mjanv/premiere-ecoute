defmodule PremiereEcoute.Discography.SingleTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single

  describe "create/1" do
    test "persists a single with its artists" do
      {:ok, artist} = Artist.create_if_not_exists(%{name: "Solo Artist"})

      {:ok, single} =
        Single.create(%Single{
          provider_ids: %{spotify: "solo_track_1"},
          name: "Solo Track",
          duration_ms: 200_000,
          artists: [artist]
        })

      assert single.id != nil
      assert single.name == "Solo Track"
      assert single.artist.name == "Solo Artist"
    end
  end

  describe "create_if_not_exists/1" do
    test "creates a new single when none matches any provider id" do
      {:ok, single} =
        Single.create_if_not_exists(%Single{
          provider_ids: %{spotify: "new_track_1"},
          name: "Brand New Track",
          artists: []
        })

      assert single.id != nil
      assert Single.get(single.id) != nil
    end

    test "returns the existing single when the spotify id already exists" do
      {:ok, existing} =
        Single.create(%Single{provider_ids: %{spotify: "dup_track_1"}, name: "Original Name", artists: []})

      {:ok, found} =
        Single.create_if_not_exists(%Single{
          provider_ids: %{spotify: "dup_track_1"},
          name: "Different Name — should not be used",
          artists: []
        })

      assert found.id == existing.id
      assert found.name == "Original Name"
    end

    test "matches on any provider key, not just the first one Elixir happens to iterate" do
      {:ok, existing} =
        Single.create(%Single{provider_ids: %{deezer: "deezer_dup_1"}, name: "Deezer Original", artists: []})

      # spotify id is new, but deezer id matches — must still resolve to the existing record
      # regardless of map iteration order between the two keys.
      {:ok, found} =
        Single.create_if_not_exists(%Single{
          provider_ids: %{spotify: "brand_new_spotify_id", deezer: "deezer_dup_1"},
          name: "Should not be created",
          artists: []
        })

      assert found.id == existing.id
      assert found.name == "Deezer Original"
      assert Single.all(where: [name: "Should not be created"]) == []
    end

    test "creates a new single when a multi-provider map matches nothing" do
      {:ok, single} =
        Single.create_if_not_exists(%Single{
          provider_ids: %{spotify: "unmatched_spotify", deezer: "unmatched_deezer"},
          name: "Genuinely New",
          artists: []
        })

      assert single.id != nil
      assert single.name == "Genuinely New"
    end

    test "falls back to create/1 when provider_ids is empty" do
      {:ok, single} = Single.create_if_not_exists(%Single{provider_ids: %{}, name: "No Provider", artists: []})

      assert single.id != nil
    end
  end

  describe "get_by_provider_id/2" do
    test "finds a single by its spotify id" do
      {:ok, created} =
        Single.create(%Single{provider_ids: %{spotify: "find_me_spotify"}, name: "Findable", artists: []})

      found = Single.get_by_provider_id(:spotify, "find_me_spotify")

      assert found.id == created.id
    end

    test "returns nil when no single matches the provider id" do
      assert Single.get_by_provider_id(:spotify, "does_not_exist") == nil
    end
  end

  describe "get_by_slug/1" do
    test "finds a single by its generated slug" do
      {:ok, created} = Single.create(%Single{provider_ids: %{spotify: "slug_track"}, name: "Sluggable Track", artists: []})

      found = Single.get_by_slug(created.slug)

      assert found.id == created.id
    end
  end

  describe "search/1" do
    test "finds singles by matching track name" do
      {:ok, _} = Single.create(%Single{provider_ids: %{spotify: "search_1"}, name: "Unique Search Term Song", artists: []})

      [result] = Single.search("Unique Search Term")

      assert result.name == "Unique Search Term Song"
    end

    test "finds singles by matching artist name" do
      {:ok, artist} = Artist.create_if_not_exists(%{name: "Very Unique Artist Name"})

      {:ok, _} =
        Single.create(%Single{provider_ids: %{spotify: "search_2"}, name: "Some Track", artists: [artist]})

      [result] = Single.search("Very Unique Artist")

      assert result.artist.name == "Very Unique Artist Name"
    end

    test "returns an empty list when nothing matches" do
      assert Single.search("nonexistent-search-term-xyz") == []
    end
  end

  describe "list_for_artist/1" do
    test "returns singles associated with the given artist" do
      {:ok, artist} = Artist.create_if_not_exists(%{name: "Prolific Artist"})

      {:ok, single} =
        Single.create(%Single{provider_ids: %{spotify: "artist_track_1"}, name: "Artist Track", artists: [artist]})

      [result] = Single.list_for_artist(artist.id)

      assert result.id == single.id
    end

    test "returns an empty list when the artist has no singles" do
      {:ok, artist} = Artist.create_if_not_exists(%{name: "Quiet Artist"})

      assert Single.list_for_artist(artist.id) == []
    end
  end
end
