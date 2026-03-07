defmodule PremiereEcoute.Radio.RadioTrackTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Radio.RadioTrack

  defp track_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        provider_ids: %{spotify: "1pKYYY0dkg23sQQXi0Q5zN"},
        name: "Around the World",
        artist: "Daft Punk",
        album: "Homework",
        duration_ms: 429_533,
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      },
      overrides
    )
  end

  describe "insert/2" do
    test "inserts a track and returns atomized provider_ids" do
      user = user_fixture()

      assert {:ok, track} = RadioTrack.insert(user.id, track_attrs())
      assert track.name == "Around the World"
      assert track.artist == "Daft Punk"
      assert track.provider_ids == %{spotify: "1pKYYY0dkg23sQQXi0Q5zN"}
    end

    test "returns error for consecutive duplicate (same provider ID)" do
      user = user_fixture()
      attrs = track_attrs()

      assert {:ok, _} = RadioTrack.insert(user.id, attrs)
      assert {:error, :consecutive_duplicate} = RadioTrack.insert(user.id, attrs)
    end

    test "inserts a second track when provider ID differs" do
      user = user_fixture()

      assert {:ok, _} = RadioTrack.insert(user.id, track_attrs(%{provider_ids: %{spotify: "aaaa"}}))
      assert {:ok, track} = RadioTrack.insert(user.id, track_attrs(%{provider_ids: %{spotify: "bbbb"}}))
      assert track.provider_ids == %{spotify: "bbbb"}
    end

    test "allows the same track for different users" do
      user1 = user_fixture()
      user2 = user_fixture()
      attrs = track_attrs()

      assert {:ok, _} = RadioTrack.insert(user1.id, attrs)
      assert {:ok, _} = RadioTrack.insert(user2.id, attrs)
    end

    test "returns changeset error when required fields are missing" do
      user = user_fixture()

      assert {:error, changeset} = RadioTrack.insert(user.id, %{provider_ids: %{spotify: "id"}})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "get/1" do
    test "returns the track with atomized provider_ids" do
      user = user_fixture()
      {:ok, inserted} = RadioTrack.insert(user.id, track_attrs())

      track = RadioTrack.get(inserted.id)
      assert track.id == inserted.id
      assert track.provider_ids == %{spotify: "1pKYYY0dkg23sQQXi0Q5zN"}
    end

    test "returns nil for unknown id" do
      assert RadioTrack.get(0) == nil
    end
  end

  describe "update_provider_ids/2" do
    test "merges new ids into existing provider_ids" do
      user = user_fixture()
      {:ok, track} = RadioTrack.insert(user.id, track_attrs())

      assert {:ok, updated} = RadioTrack.update_provider_ids(track, %{deezer: "3135556"})
      assert updated.provider_ids == %{spotify: "1pKYYY0dkg23sQQXi0Q5zN", deezer: "3135556"}
    end

    test "overwrites an existing key" do
      user = user_fixture()
      {:ok, track} = RadioTrack.insert(user.id, track_attrs())

      assert {:ok, updated} = RadioTrack.update_provider_ids(track, %{spotify: "new_id"})
      assert updated.provider_ids == %{spotify: "new_id"}
    end
  end

  describe "for_date/2" do
    test "returns tracks for the given date in chronological order" do
      user = user_fixture()
      date = ~D[2026-01-15]

      {:ok, t1} =
        RadioTrack.insert(user.id, track_attrs(%{started_at: ~U[2026-01-15 10:00:00Z]}))

      {:ok, t2} =
        RadioTrack.insert(user.id, track_attrs(%{provider_ids: %{spotify: "other"}, started_at: ~U[2026-01-15 12:00:00Z]}))

      tracks = RadioTrack.for_date(user.id, date)
      assert [^t1, ^t2] = tracks
    end

    test "excludes tracks from other dates" do
      user = user_fixture()

      RadioTrack.insert(user.id, track_attrs(%{started_at: ~U[2026-01-14 23:59:59Z]}))

      {:ok, t} =
        RadioTrack.insert(user.id, track_attrs(%{provider_ids: %{spotify: "other"}, started_at: ~U[2026-01-15 00:00:00Z]}))

      tracks = RadioTrack.for_date(user.id, ~D[2026-01-15])
      assert [^t] = tracks
    end

    test "returns empty list when no tracks exist for date" do
      user = user_fixture()
      assert [] = RadioTrack.for_date(user.id, ~D[2026-01-15])
    end
  end

  describe "delete_before/2" do
    test "deletes tracks older than the cutoff" do
      user = user_fixture()
      cutoff = ~U[2026-01-15 00:00:00Z]

      {:ok, _old} = RadioTrack.insert(user.id, track_attrs(%{started_at: ~U[2026-01-14 10:00:00Z]}))

      {:ok, _recent} =
        RadioTrack.insert(user.id, track_attrs(%{provider_ids: %{spotify: "other"}, started_at: ~U[2026-01-15 10:00:00Z]}))

      {count, nil} = RadioTrack.delete_before(user.id, cutoff)
      assert count == 1
      assert [_] = RadioTrack.for_date(user.id, ~D[2026-01-15])
    end

    test "returns zero count when nothing matches" do
      user = user_fixture()
      {:ok, _} = RadioTrack.insert(user.id, track_attrs(%{started_at: ~U[2026-01-15 10:00:00Z]}))

      {count, nil} = RadioTrack.delete_before(user.id, ~U[2026-01-14 00:00:00Z])
      assert count == 0
    end
  end
end
