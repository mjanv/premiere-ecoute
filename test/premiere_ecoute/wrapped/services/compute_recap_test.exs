defmodule PremiereEcoute.Wrapped.Services.ComputeRecapTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.Wrapped.WrappedFixtures

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Wrapped.Recap
  alias PremiereEcoute.Wrapped.Services.ComputeRecap
  alias PremiereEcoute.Wrapped.Workers

  @year Date.utc_today().year

  setup do
    stub_covers()

    {:ok, streamer: user_fixture(%{role: :streamer}), viewer: user_fixture(%{twitch: %{user_id: "viewer1"}})}
  end

  describe "topic/1" do
    test "is specific to a user" do
      assert ComputeRecap.topic(%User{id: 7}) == "wrapped:7"
    end
  end

  describe "compute/2" do
    test "stores the cards of the year", %{streamer: streamer, viewer: viewer} do
      for n <- 1..4, do: listened(streamer, n, ["#{n + 5}", "7"], others: [{"viewer2", "5"}])
      listened(streamer, 5, ["7"], visibility: :private)
      listened_single(streamer, 1, "9")

      assert {:ok, %Recap{} = recap} = ComputeRecap.compute(viewer, @year)

      assert Enum.map(recap.cards, & &1["type"]) ==
               ~w(year_in_music cover_wall first_vote top_album next_albums top_track next_tracks top_single you_and_chat recap)

      assert %{"data" => %{"albums" => 5, "minutes" => 32}, "appearance" => %{"colors" => []}} = hd(recap.cards)
      assert {recap.user_id, recap.year, recap.version} == {viewer.id, @year, Recap.version()}
      assert DateTime.diff(DateTime.utc_now(), recap.computed_at) < 5
      assert Recap.current(viewer, @year).id == recap.id
    end

    test "notifies the viewer with the stored recap", %{streamer: streamer, viewer: viewer} do
      for n <- 1..3, do: listened(streamer, n, ["8"])
      PremiereEcoute.PubSub.subscribe(ComputeRecap.topic(viewer))

      {:ok, %Recap{id: id}} = ComputeRecap.compute(viewer, @year)

      # Cards as the page reads them: plain JSON with string keys, not %Card{} structs
      assert_receive {:wrapped_computed, %Recap{id: ^id, cards: [%{"type" => "year_in_music", "data" => %{"albums" => 3}} | _]}}
    end

    test "replaces the previous recap and keeps its share token", %{streamer: streamer, viewer: viewer} do
      for n <- 1..3, do: listened(streamer, n, ["8"])
      {:ok, first} = ComputeRecap.compute(viewer, @year)
      listened(streamer, 4, ["8"])

      {:ok, second} = ComputeRecap.compute(viewer, @year)

      assert {second.id, second.share_token} == {first.id, first.share_token}
      assert %{"data" => %{"albums" => 4}} = hd(second.cards)
    end

    test "stores a recap without card below the minimum number of albums", %{streamer: streamer, viewer: viewer} do
      for n <- 1..2, do: listened(streamer, n, ["8"])

      assert {:ok, %Recap{cards: []}} = ComputeRecap.compute(viewer, @year)
    end

    test "only counts the votes of the year", %{streamer: streamer, viewer: viewer} do
      for n <- 1..3, do: listened(streamer, n, ["8"], voted_at: ~U[2026-06-01 20:00:00Z])

      assert {:ok, %Recap{cards: [_ | _]}} = ComputeRecap.compute(viewer, 2026)
      assert {:ok, %Recap{cards: []}} = ComputeRecap.compute(viewer, 2027)
    end

    test "stores a recap without card for a user without Twitch account", %{streamer: streamer} do
      for n <- 1..3, do: listened(streamer, n, ["8"])

      assert {:ok, %Recap{cards: []}} = ComputeRecap.compute(user_fixture(), @year)
    end

    test "fails without notification when the recap cannot be stored" do
      ghost = %User{id: -1}
      PremiereEcoute.PubSub.subscribe(ComputeRecap.topic(ghost))

      assert {:error, %Ecto.Changeset{}} = ComputeRecap.compute(ghost, @year)
      refute_receive {:wrapped_computed, _}
    end
  end

  describe "request/2" do
    test "enqueues the computation of one recap", %{viewer: viewer} do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %Oban.Job{}} = ComputeRecap.request(viewer, @year)

        assert_enqueued worker: Workers.ComputeRecap, queue: :wrapped, args: %{"user_id" => viewer.id, "year" => @year}
      end)
    end
  end

  describe "schedule/1" do
    test "enqueues one computation per user who voted during the year", %{streamer: streamer, viewer: viewer} do
      other = user_fixture(%{twitch: %{user_id: "viewer2"}})
      _silent = user_fixture(%{twitch: %{user_id: "viewer3"}})
      listened(streamer, 1, ["8"], others: [{"viewer2", "5"}])

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert ComputeRecap.schedule(@year) == :ok

        jobs = all_enqueued(worker: Workers.ComputeRecap)

        assert jobs |> Enum.map(& &1.args) |> Enum.sort_by(& &1["user_id"]) ==
                 Enum.sort_by(
                   [%{"user_id" => viewer.id, "year" => @year}, %{"user_id" => other.id, "year" => @year}],
                   & &1["user_id"]
                 )
      end)
    end

    test "enqueues nothing for a year without vote" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert ComputeRecap.schedule(@year) == :ok

        refute_enqueued worker: Workers.ComputeRecap
      end)
    end

    test "computes the recaps when jobs run", %{streamer: streamer, viewer: viewer} do
      listened(streamer, 1, ["8"])

      assert ComputeRecap.schedule(@year) == :ok

      assert Recap.current(viewer, @year)
      refute Recap.current(streamer, @year)
    end
  end
end
