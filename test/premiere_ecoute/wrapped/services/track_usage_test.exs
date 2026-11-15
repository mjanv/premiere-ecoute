defmodule PremiereEcoute.Wrapped.Services.TrackUsageTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.Wrapped.WrappedFixtures

  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Events.WrappedShared
  alias PremiereEcoute.Events.WrappedViewed
  alias PremiereEcoute.Wrapped.Services.TrackUsage

  @year Date.utc_today().year

  describe "viewed/1" do
    test "records that the viewer opened their Wrapped" do
      user = user_fixture()

      assert TrackUsage.viewed(recap_fixture(user, @year)) == :ok

      assert [%WrappedViewed{id: id, year: @year}] = Store.read("wrapped_recap-#{user.id}")
      assert id == user.id
    end
  end

  describe "shared/1" do
    test "records that the viewer shared their Wrapped" do
      user = user_fixture()

      assert TrackUsage.shared(recap_fixture(user, @year)) == :ok

      assert [%WrappedShared{id: id, year: @year}] = Store.read("wrapped_recap-#{user.id}")
      assert id == user.id
    end
  end

  describe "viewed/2 and shared/2" do
    test "record the render the Wrapped was played with" do
      user = user_fixture()
      recap = recap_fixture(user, @year)

      assert TrackUsage.viewed(recap, :shader) == :ok
      assert TrackUsage.shared(recap, :shader) == :ok
      assert TrackUsage.viewed(recap) == :ok

      assert [%WrappedViewed{render: "shader"}, %WrappedShared{render: "shader"}, %WrappedViewed{render: nil}] =
               Store.read("wrapped_recap-#{user.id}")
    end
  end

  describe "viewed/1 and shared/1" do
    test "keep the events of each viewer in order, in their own stream" do
      [one, two] = for _ <- 1..2, do: user_fixture()
      [recap, other] = [recap_fixture(one, @year), recap_fixture(two, @year - 1)]

      TrackUsage.viewed(recap)
      TrackUsage.shared(recap)
      TrackUsage.viewed(recap)
      TrackUsage.viewed(other)

      assert [%WrappedViewed{}, %WrappedShared{}, %WrappedViewed{}] = Store.read("wrapped_recap-#{one.id}")
      assert [%WrappedViewed{year: year}] = Store.read("wrapped_recap-#{two.id}")
      assert year == @year - 1
    end
  end
end
