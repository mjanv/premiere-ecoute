defmodule PremiereEcoute.BillboardsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Billboards
  alias PremiereEcoute.Billboards.Billboard

  import PremiereEcoute.AccountsFixtures

  setup do
    user = user_fixture()

    {:ok, billboard} =
      Billboards.create_billboard(%Billboard{
        title: "Test Billboard",
        submissions: [],
        status: :active,
        user_id: user.id
      })

    {:ok, billboard: billboard, user: user}
  end

  describe "add_submission/3" do
    test "can store 10 submissions one after the other", %{billboard: billboard} do
      {updated_billboard, _tokens} =
        Enum.reduce(1..10, {billboard, []}, fn i, {current_billboard, tokens} ->
          url = "https://open.spotify.com/playlist/test-playlist-#{i}"
          pseudo = "user#{i}"

          {:ok, updated_billboard, deletion_token} = Billboards.add_submission(current_billboard, url, pseudo)

          assert length(updated_billboard.submissions) == i
          assert deletion_token != nil

          latest_submission = hd(updated_billboard.submissions)
          assert latest_submission["url"] == url
          assert latest_submission["pseudo"] == pseudo
          assert latest_submission["deletion_token"] == deletion_token
          assert latest_submission["submitted_at"] != nil

          {updated_billboard, [deletion_token | tokens]}
        end)

      assert length(updated_billboard.submissions) == 10

      urls = Enum.map(updated_billboard.submissions, fn s -> s["url"] end)
      assert length(Enum.uniq(urls)) == 10

      tokens = Enum.map(updated_billboard.submissions, fn s -> s["deletion_token"] end)
      assert length(Enum.uniq(tokens)) == 10

      submission_times = Enum.map(updated_billboard.submissions, fn s -> s["submitted_at"] end)
      sorted_times = Enum.sort(submission_times, {:desc, DateTime})
      assert submission_times == sorted_times
    end

    test "rejects duplicate URLs", %{billboard: billboard} do
      url = "https://open.spotify.com/playlist/duplicate-test"

      {:ok, updated_billboard, _token} = Billboards.add_submission(billboard, url, "user1")
      {:error, :url_already_exists} = Billboards.add_submission(updated_billboard, url, "user2")
    end

    test "rejects submissions to inactive billboards", %{user: user} do
      {:ok, inactive_billboard} =
        Billboards.create_billboard(%Billboard{
          title: "Inactive Billboard",
          submissions: [],
          status: :stopped,
          user_id: user.id
        })

      {:error, :billboard_not_active} = Billboards.add_submission(inactive_billboard, "https://example.com/playlist", "user1")
    end
  end

  describe "remove_submission/2" do
    test "can remove submission by valid index", %{billboard: billboard} do
      {:ok, billboard, _token1} = Billboards.add_submission(billboard, "https://playlist1.com", "user1")
      {:ok, billboard, _token2} = Billboards.add_submission(billboard, "https://playlist2.com", "user2")
      {:ok, billboard, _token3} = Billboards.add_submission(billboard, "https://playlist3.com", "user3")

      assert length(billboard.submissions) == 3

      {:ok, updated_billboard} = Billboards.remove_submission(billboard, 1)

      assert length(updated_billboard.submissions) == 2

      remaining_urls = Enum.map(updated_billboard.submissions, fn s -> s["url"] end)
      assert "https://playlist2.com" not in remaining_urls
      assert "https://playlist1.com" in remaining_urls
      assert "https://playlist3.com" in remaining_urls
    end

    test "can remove first submission (index 0)", %{billboard: billboard} do
      {:ok, billboard, _token1} = Billboards.add_submission(billboard, "https://playlist1.com", "user1")
      {:ok, billboard, _token2} = Billboards.add_submission(billboard, "https://playlist2.com", "user2")

      assert length(billboard.submissions) == 2

      {:ok, updated_billboard} = Billboards.remove_submission(billboard, 0)

      assert length(updated_billboard.submissions) == 1
      remaining_submission = hd(updated_billboard.submissions)
      assert remaining_submission["url"] == "https://playlist1.com"
    end

    test "can remove last submission", %{billboard: billboard} do
      {:ok, billboard, _token1} = Billboards.add_submission(billboard, "https://playlist1.com", "user1")
      {:ok, billboard, _token2} = Billboards.add_submission(billboard, "https://playlist2.com", "user2")

      assert length(billboard.submissions) == 2

      {:ok, updated_billboard} = Billboards.remove_submission(billboard, 1)

      assert length(updated_billboard.submissions) == 1
      remaining_submission = hd(updated_billboard.submissions)
      assert remaining_submission["url"] == "https://playlist2.com"
    end

    test "returns error for invalid index (negative)", %{billboard: billboard} do
      {:ok, billboard, _token} = Billboards.add_submission(billboard, "https://playlist1.com", "user1")

      {:error, :invalid_index} = Billboards.remove_submission(billboard, -1)
    end

    test "returns error for invalid index (out of bounds)", %{billboard: billboard} do
      {:ok, billboard, _token} = Billboards.add_submission(billboard, "https://playlist1.com", "user1")

      {:error, :invalid_index} = Billboards.remove_submission(billboard, 1)

      {:error, :invalid_index} = Billboards.remove_submission(billboard, 5)
    end

    test "returns error for empty submissions list", %{billboard: billboard} do
      assert billboard.submissions == []

      {:error, :invalid_index} = Billboards.remove_submission(billboard, 0)
    end
  end

  describe "remove_submission_by_token/2" do
    test "can remove submission by valid deletion token", %{billboard: billboard} do
      {:ok, billboard, token1} = Billboards.add_submission(billboard, "https://playlist1.com", "user1")
      {:ok, billboard, token2} = Billboards.add_submission(billboard, "https://playlist2.com", "user2")
      {:ok, billboard, token3} = Billboards.add_submission(billboard, "https://playlist3.com", "user3")

      assert length(billboard.submissions) == 3

      {:ok, updated_billboard} = Billboards.remove_submission_by_token(billboard, token2)

      assert length(updated_billboard.submissions) == 2

      remaining_urls = Enum.map(updated_billboard.submissions, fn s -> s["url"] end)
      assert "https://playlist2.com" not in remaining_urls
      assert "https://playlist1.com" in remaining_urls
      assert "https://playlist3.com" in remaining_urls

      remaining_tokens = Enum.map(updated_billboard.submissions, fn s -> s["deletion_token"] end)
      assert token1 in remaining_tokens
      assert token3 in remaining_tokens
      assert token2 not in remaining_tokens
    end

    test "returns error for non-existent token", %{billboard: billboard} do
      {:ok, billboard, _token} = Billboards.add_submission(billboard, "https://playlist1.com", "user1")

      {:error, :token_not_found} = Billboards.remove_submission_by_token(billboard, "non-existent-token")
    end

    test "returns error for empty token string", %{billboard: billboard} do
      {:ok, billboard, _token} = Billboards.add_submission(billboard, "https://playlist1.com", "user1")

      {:error, :token_not_found} = Billboards.remove_submission_by_token(billboard, "")
    end

    test "works with empty submissions list", %{billboard: billboard} do
      assert billboard.submissions == []

      {:error, :token_not_found} = Billboards.remove_submission_by_token(billboard, "any-token")
    end

    test "handles tokens in struct format (with atom keys)", %{billboard: billboard} do
      submission_with_atom_key = %{
        "url" => "https://playlist1.com",
        "pseudo" => "user1",
        "submitted_at" => DateTime.utc_now(),
        deletion_token: "test-token-atom"
      }

      {:ok, billboard} = Billboards.update_billboard(billboard, %{submissions: [submission_with_atom_key]})

      {:ok, updated_billboard} = Billboards.remove_submission_by_token(billboard, "test-token-atom")

      assert updated_billboard.submissions == []
    end
  end

  describe "activate_billboard/1" do
    test "can activate a stopped billboard", %{user: user} do
      {:ok, stopped_billboard} =
        Billboards.create_billboard(%Billboard{
          title: "Stopped Billboard",
          submissions: [],
          status: :stopped,
          user_id: user.id
        })

      assert stopped_billboard.status == :stopped

      {:ok, activated_billboard} = Billboards.activate_billboard(stopped_billboard)

      assert activated_billboard.status == :active
      assert activated_billboard.id == stopped_billboard.id
      assert activated_billboard.title == stopped_billboard.title
    end

    test "can activate an already active billboard", %{billboard: billboard} do
      assert billboard.status == :active

      {:ok, still_active_billboard} = Billboards.activate_billboard(billboard)

      assert still_active_billboard.status == :active
      assert still_active_billboard.id == billboard.id
    end
  end

  describe "stop_billboard/1" do
    test "can stop an active billboard", %{billboard: billboard} do
      assert billboard.status == :active

      {:ok, stopped_billboard} = Billboards.stop_billboard(billboard)

      assert stopped_billboard.status == :stopped
      assert stopped_billboard.id == billboard.id
      assert stopped_billboard.title == billboard.title
    end

    test "can stop an already stopped billboard", %{user: user} do
      {:ok, stopped_billboard} =
        Billboards.create_billboard(%Billboard{
          title: "Already Stopped Billboard",
          submissions: [],
          status: :stopped,
          user_id: user.id
        })

      assert stopped_billboard.status == :stopped

      {:ok, still_stopped_billboard} = Billboards.stop_billboard(stopped_billboard)

      assert still_stopped_billboard.status == :stopped
      assert still_stopped_billboard.id == stopped_billboard.id
    end
  end
end
