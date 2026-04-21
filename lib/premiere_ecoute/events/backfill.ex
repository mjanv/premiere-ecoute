defmodule PremiereEcoute.Events.Backfill do
  @moduledoc """
  Backfills historical events from relational data for entities that predate
  event sourcing.

  Each function is idempotent: already-backfilled records are skipped in a
  single bulk query before insertion so the functions are safe to re-run.

  Events are inserted directly into `event_store.events` with `created_at`
  set to the row's `inserted_at`, preserving historical accuracy in analytics
  charts.

  ## Usage (from IEx or production console)

      # Run all backfills at once
      PremiereEcoute.Events.Backfill.run_all()

      # Run a single backfill
      PremiereEcoute.Events.Backfill.accounts()
      PremiereEcoute.Events.Backfill.artists()
      PremiereEcoute.Events.Backfill.albums()
      PremiereEcoute.Events.Backfill.library_playlists()
      PremiereEcoute.Events.Backfill.collections()
      PremiereEcoute.Events.Backfill.wantlist_items()
  """

  import Ecto.Query

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Collections.CollectionSession
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.AlbumArtist
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Wantlists.Wantlist
  alias PremiereEcoute.Wantlists.WantlistItem

  @doc "Runs all backfills in sequence. Returns a summary map."
  @spec run_all() :: %{atom() => %{inserted: non_neg_integer(), skipped: non_neg_integer()}}
  def run_all do
    ~w(accounts artists albums library_playlists collections wantlist_items)a
    |> Map.new(fn name ->
      result = apply(__MODULE__, name, [])
      IO.puts("[Backfill] #{name}: inserted=#{result.inserted} skipped=#{result.skipped}")
      {name, result}
    end)
  end

  @doc "Backfills AccountCreated for all users."
  @spec accounts() :: %{inserted: non_neg_integer(), skipped: non_neg_integer()}
  def accounts do
    event_type = "Elixir.PremiereEcoute.Events.AccountCreated"

    rows = Repo.all(from u in User, select: %{id: u.id, inserted_at: u.inserted_at})
    existing = existing_ids(event_type)

    {ins, skip} =
      Enum.reduce(rows, {0, 0}, fn row, {i, s} ->
        if MapSet.member?(existing, row.id) do
          {i, s + 1}
        else
          insert_event(event_type, %{"id" => row.id}, row.inserted_at)
          {i + 1, s}
        end
      end)

    %{inserted: ins, skipped: skip}
  end

  @doc "Backfills ArtistAdded for all artists."
  @spec artists() :: %{inserted: non_neg_integer(), skipped: non_neg_integer()}
  def artists do
    event_type = "Elixir.PremiereEcoute.Events.ArtistAdded"

    rows = Repo.all(from a in Artist, select: %{id: a.id, name: a.name, inserted_at: a.inserted_at})
    existing = existing_ids(event_type)

    {ins, skip} =
      Enum.reduce(rows, {0, 0}, fn row, {i, s} ->
        if MapSet.member?(existing, row.id) do
          {i, s + 1}
        else
          insert_event(event_type, %{"id" => row.id, "name" => row.name}, row.inserted_at)
          {i + 1, s}
        end
      end)

    %{inserted: ins, skipped: skip}
  end

  @doc "Backfills AlbumAdded for all albums."
  @spec albums() :: %{inserted: non_neg_integer(), skipped: non_neg_integer()}
  def albums do
    event_type = "Elixir.PremiereEcoute.Events.AlbumAdded"

    rows =
      Repo.all(
        from a in Album,
          left_join: aa in AlbumArtist,
          on: aa.album_id == a.id,
          left_join: ar in Artist,
          on: ar.id == aa.artist_id,
          group_by: [a.id, a.name, a.inserted_at],
          select: %{id: a.id, name: a.name, artist: min(ar.name), inserted_at: a.inserted_at}
      )

    existing = existing_ids(event_type)

    {ins, skip} =
      Enum.reduce(rows, {0, 0}, fn row, {i, s} ->
        if MapSet.member?(existing, row.id) do
          {i, s + 1}
        else
          insert_event(event_type, %{"id" => row.id, "name" => row.name, "artist" => row.artist}, row.inserted_at)
          {i + 1, s}
        end
      end)

    %{inserted: ins, skipped: skip}
  end

  @doc "Backfills LibraryPlaylistAdded for all library playlists."
  @spec library_playlists() :: %{inserted: non_neg_integer(), skipped: non_neg_integer()}
  def library_playlists do
    event_type = "Elixir.PremiereEcoute.Events.LibraryPlaylistAdded"

    rows =
      Repo.all(
        from p in LibraryPlaylist,
          select: %{user_id: p.user_id, provider: p.provider, inserted_at: p.inserted_at}
      )

    # AIDEV-NOTE: LibraryPlaylistAdded uses user_id as the event id (streams to
    # the user aggregate). Idempotency checks against user_id, not playlist id.
    existing = existing_ids(event_type)

    {ins, skip} =
      Enum.reduce(rows, {0, 0}, fn row, {i, s} ->
        if MapSet.member?(existing, row.user_id) do
          {i, s + 1}
        else
          insert_event(event_type, %{"id" => row.user_id, "provider" => to_string(row.provider)}, row.inserted_at)
          {i + 1, s}
        end
      end)

    %{inserted: ins, skipped: skip}
  end

  @doc "Backfills CollectionCreated for all collection sessions."
  @spec collections() :: %{inserted: non_neg_integer(), skipped: non_neg_integer()}
  def collections do
    event_type = "Elixir.PremiereEcoute.Events.CollectionCreated"

    rows = Repo.all(from s in CollectionSession, select: %{id: s.id, inserted_at: s.inserted_at})
    existing = existing_ids(event_type)

    {ins, skip} =
      Enum.reduce(rows, {0, 0}, fn row, {i, s} ->
        if MapSet.member?(existing, row.id) do
          {i, s + 1}
        else
          insert_event(event_type, %{"id" => row.id}, row.inserted_at)
          {i + 1, s}
        end
      end)

    %{inserted: ins, skipped: skip}
  end

  @doc "Backfills AddedToWantlist for all wantlist items."
  @spec wantlist_items() :: %{inserted: non_neg_integer(), skipped: non_neg_integer()}
  def wantlist_items do
    event_type = "Elixir.PremiereEcoute.Events.AddedToWantlist"

    rows =
      Repo.all(
        from wi in WantlistItem,
          join: w in Wantlist,
          on: w.id == wi.wantlist_id,
          select: %{
            item_id: wi.id,
            user_id: w.user_id,
            type: wi.type,
            album_id: wi.album_id,
            single_id: wi.single_id,
            artist_id: wi.artist_id,
            inserted_at: wi.inserted_at
          }
      )

    # AIDEV-NOTE: idempotency key is the wantlist_item id stored in a separate
    # "item_id" field in metadata, since the event id field holds user_id.
    existing = existing_item_ids(event_type)

    {ins, skip} =
      Enum.reduce(rows, {0, 0}, fn row, {i, s} ->
        if MapSet.member?(existing, row.item_id) do
          {i, s + 1}
        else
          record_id = row.album_id || row.single_id || row.artist_id

          insert_event(
            event_type,
            %{"id" => row.user_id, "type" => to_string(row.type), "record_id" => record_id},
            row.inserted_at,
            %{"backfill" => true, "item_id" => row.item_id}
          )

          {i + 1, s}
        end
      end)

    %{inserted: ins, skipped: skip}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Returns a MapSet of integer ids already present in the event store for the
  # given event type, extracted from data->>'id'.
  defp existing_ids(event_type) do
    Repo.all(
      from e in {"events", nil},
        prefix: "event_store",
        where: e.event_type == ^event_type,
        select: type(fragment("(?->>'id')::integer", e.data), :integer)
    )
    |> MapSet.new()
  end

  # For wantlist items, idempotency uses metadata->>'item_id' (an integer)
  # because the event id holds user_id which is not unique per item.
  defp existing_item_ids(event_type) do
    Repo.all(
      from e in {"events", nil},
        prefix: "event_store",
        where: e.event_type == ^event_type,
        where: not is_nil(fragment("?->>'item_id'", e.metadata)),
        select: type(fragment("(?->>'item_id')::integer", e.metadata), :integer)
    )
    |> MapSet.new()
  end

  defp insert_event(event_type, data, created_at, metadata \\ %{"backfill" => true}) do
    Repo.insert_all(
      "events",
      [
        %{
          event_id: Ecto.UUID.dump!(UUID.uuid4()),
          event_type: event_type,
          data: data,
          metadata: metadata,
          created_at: created_at
        }
      ],
      prefix: "event_store"
    )
  end
end
