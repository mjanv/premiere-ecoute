defmodule PremiereEcoute.BillboardsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Billboards
  alias PremiereEcoute.Billboards.Billboard

  import PremiereEcoute.AccountsFixtures

  defp create_test_billboard(status \\ :active) do
    user = user_fixture()

    {:ok, billboard} =
      Billboards.create_billboard(%Billboard{
        title: "Test Billboard",
        submissions: [],
        status: status,
        user_id: user.id
      })

    billboard
  end

  describe "add_submission/3" do
    test "can store 10 submissions one after the other" do
      billboard = create_test_billboard()

      {updated_billboard, _tokens} =
        Enum.reduce(1..10, {billboard, []}, fn i, {current_billboard, tokens} ->
          url = "https://open.spotify.com/playlist/test-playlist-#{i}"
          pseudo = "user#{i}"

          # Add submission
          {:ok, updated_billboard, deletion_token} =
            Billboards.add_submission(current_billboard, url, pseudo)

          # Verify submission was added
          assert length(updated_billboard.submissions) == i
          assert deletion_token != nil

          # Verify the submission contains correct data
          latest_submission = hd(updated_billboard.submissions)
          assert latest_submission["url"] == url
          assert latest_submission["pseudo"] == pseudo
          assert latest_submission["deletion_token"] == deletion_token
          assert latest_submission["submitted_at"] != nil

          {updated_billboard, [deletion_token | tokens]}
        end)

      assert length(updated_billboard.submissions) == 10

      # Verify all submissions are unique URLs
      urls = Enum.map(updated_billboard.submissions, fn s -> s["url"] end)
      assert length(Enum.uniq(urls)) == 10

      # Verify all deletion tokens are unique
      tokens = Enum.map(updated_billboard.submissions, fn s -> s["deletion_token"] end)
      assert length(Enum.uniq(tokens)) == 10

      # Verify submissions are in reverse chronological order (newest first)
      submission_times = Enum.map(updated_billboard.submissions, fn s -> s["submitted_at"] end)
      sorted_times = Enum.sort(submission_times, {:desc, DateTime})
      assert submission_times == sorted_times
    end

    test "rejects duplicate URLs" do
      billboard = create_test_billboard()
      url = "https://open.spotify.com/playlist/duplicate-test"

      # Add first submission successfully
      {:ok, updated_billboard, _token} =
        Billboards.add_submission(billboard, url, "user1")

      # Try to add the same URL again - should fail
      {:error, :url_already_exists} =
        Billboards.add_submission(updated_billboard, url, "user2")
    end

    test "rejects submissions to inactive billboards" do
      # Create inactive billboard
      billboard = create_test_billboard(:stopped)

      # Try to add submission - should fail
      {:error, :billboard_not_active} =
        Billboards.add_submission(billboard, "https://example.com/playlist", "user1")
    end
  end
end
