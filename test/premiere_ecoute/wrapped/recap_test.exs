defmodule PremiereEcoute.Wrapped.RecapTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.Wrapped.WrappedFixtures

  alias PremiereEcoute.Wrapped.Appearance
  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Recap

  @year Date.utc_today().year

  setup do
    {:ok, user: user_fixture()}
  end

  defp attrs(overrides \\ %{}),
    do: Map.merge(%{cards: [%{"type" => "recap"}], version: Recap.version(), computed_at: DateTime.utc_now(:second)}, overrides)

  describe "year?/1" do
    test "accepts the years from 2026 to the current one" do
      assert Recap.year?(2026)
      assert Recap.year?(@year)
      refute Recap.year?(2025)
      refute Recap.year?(@year + 1)
    end
  end

  describe "store/3" do
    test "inserts the recap of a user with a share token", %{user: user} do
      assert {:ok, %Recap{} = recap} = Recap.store(user.id, @year, attrs())

      assert {recap.user_id, recap.year, recap.version} == {user.id, @year, Recap.version()}
      assert recap.cards == [%{"type" => "recap"}]
      assert recap.computed_at
      assert recap.share_token =~ ~r/^[A-Za-z0-9_-]{12}$/
    end

    test "replaces the cards of an existing recap and keeps its share token", %{user: user} do
      {:ok, first} = Recap.store(user.id, @year, attrs())

      assert {:ok, second} = Recap.store(user.id, @year, attrs(%{cards: []}))

      assert {second.id, second.share_token} == {first.id, first.share_token}
      assert Recap.get(first.id).cards == []
    end

    test "keeps one recap per user and per year", %{user: user} do
      {:ok, this_year} = Recap.store(user.id, @year, attrs())
      {:ok, last_year} = Recap.store(user.id, @year - 1, attrs())
      {:ok, other_user} = Recap.store(user_fixture().id, @year, attrs())

      assert [this_year.id, last_year.id, other_user.id] |> Enum.uniq() |> length() == 3
      assert [this_year.share_token, last_year.share_token, other_user.share_token] |> Enum.uniq() |> length() == 3
    end

    test "ignores a share token given by the caller", %{user: user} do
      assert {:ok, recap} = Recap.store(user.id, @year, attrs(%{share_token: "chosen"}))

      refute recap.share_token == "chosen"
    end

    test "brings a recap of an older version back to the current one, with the same token", %{user: user} do
      {:ok, old} = Recap.store(user.id, @year, attrs(%{version: Recap.version() - 1}))
      refute Recap.current(user, @year)

      assert {:ok, _} = Recap.store(user.id, @year, attrs())

      assert %Recap{id: id, share_token: token} = Recap.current(user, @year)
      assert {id, token} == {old.id, old.share_token}
    end

    test "stores cards as plain JSON", %{user: user} do
      card = %Card{
        type: :cover_wall,
        appearance: %Appearance{cover_url: "https://cover", colors: ["#fff"]},
        data: %{covers: []}
      }

      {:ok, recap} = Recap.store(user.id, @year, attrs(%{cards: [card]}))

      assert Recap.get(recap.id).cards == [
               %{
                 "type" => "cover_wall",
                 "appearance" => %{"cover_url" => "https://cover", "colors" => ["#fff"]},
                 "preview" => nil,
                 "data" => %{"covers" => []}
               }
             ]
    end

    test "rejects a recap without computation time", %{user: user} do
      assert {:error, changeset} = Recap.store(user.id, @year, attrs(%{computed_at: nil}))
      assert %{computed_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects a recap for an unknown user" do
      assert {:error, changeset} = Recap.store(-1, @year, attrs())
      assert %{user_id: [_]} = errors_on(changeset)
    end
  end

  describe "delete/1" do
    test "deletes a recap, which frees its share link", %{user: user} do
      recap = recap_fixture(user, @year)
      other = recap_fixture(user, @year - 1)

      assert {:ok, %Recap{}} = Recap.delete(recap)

      refute Recap.current(user, @year)
      refute Recap.shared(@year, recap.share_token)
      assert Recap.current(user, @year - 1).id == other.id
    end

    test "gives a new share token to a recap stored again after a deletion", %{user: user} do
      recap = recap_fixture(user, @year)
      {:ok, _} = Recap.delete(recap)

      again = recap_fixture(user, @year)

      refute again.id == recap.id
      refute again.share_token == recap.share_token
    end

    test "succeeds on a recap that is already deleted", %{user: user} do
      recap = recap_fixture(user, @year)
      {:ok, _} = Recap.delete(recap)

      assert {:ok, %Recap{}} = Recap.delete(recap)
    end
  end

  describe "current/2" do
    test "fetches the recap of a user for a year", %{user: user} do
      recap = recap_fixture(user, @year)

      assert Recap.current(user, @year).id == recap.id
    end

    test "finds nothing for another year or another user", %{user: user} do
      recap_fixture(user, @year)

      refute Recap.current(user, @year - 1)
      refute Recap.current(user_fixture(), @year)
    end

    test "hides a recap computed with another version", %{user: user} do
      recap_fixture(user, @year, %{version: Recap.version() - 1})

      refute Recap.current(user, @year)
    end
  end

  describe "shared/2" do
    test "fetches a recap from its year and share token", %{user: user} do
      recap = recap_fixture(user, @year)

      assert Recap.shared(@year, recap.share_token).id == recap.id
    end

    test "finds nothing for an unknown token or the token of another year", %{user: user} do
      recap = recap_fixture(user, @year)

      refute Recap.shared(@year, "unknown")
      refute Recap.shared(@year - 1, recap.share_token)
    end

    test "hides a recap computed with another version", %{user: user} do
      recap = recap_fixture(user, @year, %{version: Recap.version() + 1})

      refute Recap.shared(@year, recap.share_token)
    end
  end
end
