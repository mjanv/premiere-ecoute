defmodule PremiereEcoute.Events.BackfillTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Events.Backfill
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Wantlists

  # Backfill's event_type strings are fixed module constants, not test-scoped, so every
  # assertion here targets a specific fixture-generated id via a scoped query instead of
  # relying on absolute counts — safe regardless of whether event_store.events rows from
  # this or other test files persist across runs.

  defp events_for(event_type, id) do
    Repo.all(
      from(e in {"events", nil},
        prefix: "event_store",
        where: e.event_type == ^event_type,
        where: fragment("(?->>'id')::text", e.data) == ^to_string(id),
        select: %{data: e.data, metadata: e.metadata, created_at: e.created_at}
      )
    )
  end

  defp events_by_item_id(event_type, item_id) do
    Repo.all(
      from(e in {"events", nil},
        prefix: "event_store",
        where: e.event_type == ^event_type,
        where: fragment("?->>'item_id'", e.metadata) == ^to_string(item_id),
        select: %{data: e.data, metadata: e.metadata, created_at: e.created_at}
      )
    )
  end

  # accounts/0 is not covered here: this test database's event_store.events already has
  # AccountCreated rows with non-integer (UUID string) ids, permanently left behind by
  # test/premiere_ecoute/event_store_test.exs against the same real, unrollbackable table.
  # existing_ids/1's `(?->>'id')::integer` cast raises on that data instead of returning NULL,
  # so accounts/0 (and run_all/0, which calls it) currently crash in this test database. This
  # is worse than the original review's "silently skips" framing — confirmed empirically while
  # writing these tests — but is out of scope here per direction: test what's testable, don't
  # fix the crash or touch event_store_test.exs's pollution.

  describe "albums/0" do
    test "captures the artist name via the left join even with multiple artists" do
      {:ok, album} = Album.create(album_fixture())

      Backfill.albums()

      assert [event] = events_for("Elixir.PremiereEcoute.Events.AlbumAdded", album.id)
      assert event.data["name"] == album.name
      assert event.data["artist"] == "Sample Artist"
    end

    test "is idempotent across repeated runs" do
      {:ok, album} = Album.create(album_fixture())

      Backfill.albums()
      Backfill.albums()

      assert [_one_event] = events_for("Elixir.PremiereEcoute.Events.AlbumAdded", album.id)
    end
  end

  describe "wantlist_items/0 (metadata-based idempotency key)" do
    test "inserts AddedToWantlist keyed by user_id, with item_id tracked in metadata for idempotency" do
      user = user_fixture()
      {:ok, album} = Album.create(album_fixture())
      {:ok, item} = Wantlists.add_item(user.id, :album, album.id)

      Backfill.wantlist_items()

      assert [event] = events_by_item_id("Elixir.PremiereEcoute.Events.AddedToWantlist", item.id)
      assert event.data["id"] == user.id
      assert event.data["type"] == "album"
      assert event.data["record_id"] == album.id
      assert event.metadata["item_id"] == item.id
    end

    test "is idempotent: a second run does not insert a duplicate for the same item_id" do
      user = user_fixture()
      {:ok, album} = Album.create(album_fixture())
      {:ok, item} = Wantlists.add_item(user.id, :album, album.id)

      Backfill.wantlist_items()
      Backfill.wantlist_items()

      assert [_one_event] = events_by_item_id("Elixir.PremiereEcoute.Events.AddedToWantlist", item.id)
    end

    test "two different users wantlisting the same album each get their own event" do
      user1 = user_fixture()
      user2 = user_fixture()
      {:ok, album} = Album.create(album_fixture())

      {:ok, item1} = Wantlists.add_item(user1.id, :album, album.id)
      {:ok, item2} = Wantlists.add_item(user2.id, :album, album.id)

      Backfill.wantlist_items()

      assert [event1] = events_by_item_id("Elixir.PremiereEcoute.Events.AddedToWantlist", item1.id)
      assert [event2] = events_by_item_id("Elixir.PremiereEcoute.Events.AddedToWantlist", item2.id)
      assert event1.data["id"] == user1.id
      assert event2.data["id"] == user2.id
    end
  end

  describe "idempotency against schema drift (documents a known fragility)" do
    test "existing_ids/1 raises when an existing row's data->>'id' is not a valid integer" do
      # Simulates an event inserted by older code, or a differently-shaped event that
      # coincidentally shares the same event_type, where "id" is absent or not an integer.
      # This does NOT silently skip the row, as the review originally framed it: Postgres's
      # `(?->>'id')::integer` cast raises invalid_text_representation on non-numeric input,
      # so any backfill run over a type with even one malformed row crashes outright rather
      # than degrading to a duplicate-insert risk. This test locks in that real behavior so a
      # future change to the extraction query is a deliberate choice, not a silent regression.
      event_type = "Elixir.PremiereEcoute.Events.CollectionCreated"

      Repo.insert_all(
        "events",
        [
          %{
            event_id: Ecto.UUID.dump!(UUID.uuid4()),
            event_type: event_type,
            data: %{"id" => "not-a-valid-integer"},
            metadata: %{},
            created_at: DateTime.utc_now()
          }
        ],
        prefix: "event_store"
      )

      assert_raise Postgrex.Error, ~r/invalid input syntax for type integer/, fn ->
        Backfill.collections()
      end
    end
  end
end
