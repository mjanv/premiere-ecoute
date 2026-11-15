defmodule PremiereEcoute.WrappedTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.Wrapped.ListenFixtures
  import PremiereEcoute.Wrapped.WrappedFixtures

  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Events.WrappedShared
  alias PremiereEcoute.Events.WrappedViewed
  alias PremiereEcoute.Wrapped
  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Recap
  alias PremiereEcoute.Wrapped.Workers.ComputeRecap

  @year Date.utc_today().year

  setup do
    stub_covers()

    {:ok, user: user_fixture(%{twitch: %{user_id: "viewer1"}})}
  end

  describe "context module delegations" do
    test "delegates year? to Recap.year?/1" do
      assert Wrapped.year?(@year)
      refute Wrapped.year?(2025)
    end

    test "delegates get_recap to Recap.current/2", %{user: user} do
      recap = recap_fixture(user, @year)

      assert Wrapped.get_recap(user, @year).id == recap.id
      refute Wrapped.get_recap(user, @year - 1)
    end

    test "delegates get_shared_recap to Recap.shared/2", %{user: user} do
      recap = recap_fixture(user, @year)

      assert Wrapped.get_shared_recap(@year, recap.share_token).id == recap.id
      refute Wrapped.get_shared_recap(@year, "unknown")
    end

    test "delegates delete_recap to Recap.delete/1", %{user: user} do
      recap = recap_fixture(user, @year)

      assert {:ok, %Recap{}} = Wrapped.delete_recap(recap)
      refute Wrapped.get_recap(user, @year)
    end

    test "delegates topic to ComputeRecap.topic/1", %{user: user} do
      assert Wrapped.topic(user) == "wrapped:#{user.id}"
    end

    test "delegates compute to ComputeRecap.compute/2", %{user: user} do
      assert {:ok, %Recap{cards: []}} = Wrapped.compute(user, @year)
      assert Wrapped.get_recap(user, @year)
    end

    test "delegates request_recap to ComputeRecap.request/2", %{user: user} do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, %Oban.Job{}} = Wrapped.request_recap(user, @year)

        assert_enqueued worker: ComputeRecap, args: %{"user_id" => user.id, "year" => @year}
      end)
    end

    test "delegates schedule to ComputeRecap.schedule/1", %{user: user} do
      listened(user_fixture(%{role: :streamer}), 1, ["8"])

      assert Wrapped.schedule(@year) == :ok
      assert Wrapped.get_recap(user, @year)
    end

    test "delegates cards to BuildCards.cards/1" do
      assert [%Card{type: :year_in_music} | _] = Wrapped.cards(for n <- 1..3, do: album_listen(n, %{score: 8.0}))
    end

    test "delegates demo_cards to BuildCards.demo_cards/0" do
      for n <- 1..3, do: album_record(n)

      assert [%{"type" => "year_in_music"} | _] = Wrapped.demo_cards()
    end

    test "delegates previews to ResolvePreviews.previews/1" do
      assert Wrapped.previews([%{"preview" => %{"artist" => "a", "name" => "t"}}, %{"preview" => nil}]) == [nil, nil]
    end

    test "delegates viewed and shared to TrackUsage", %{user: user} do
      recap = recap_fixture(user, @year)

      assert Wrapped.viewed(recap) == :ok
      assert Wrapped.shared(recap) == :ok

      assert [%WrappedViewed{year: @year}, %WrappedShared{year: @year}] = Store.read("wrapped_recap-#{user.id}")
    end
  end
end
