defmodule PremiereEcouteWeb.Mcp.Components.Radio.GetTracksTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.AccountsFixtures

  alias Hermes.Server.Frame
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Radio.RadioTrack
  alias PremiereEcoute.Repo
  alias PremiereEcouteWeb.Mcp.Components.Radio.GetTracks

  defp decode(resp) do
    [%{"text" => json}] = resp.content
    Jason.decode!(json)
  end

  defp public_streamer do
    user = user_fixture()
    {:ok, user} = User.edit_user_profile(user, %{radio_settings: %{visibility: :public, enabled: true}})
    user
  end

  defp insert_radio_track(user, attrs \\ %{}) do
    defaults = %{
      user_id: user.id,
      name: "Track #{System.unique_integer([:positive])}",
      artist: "Artist",
      album: "Album",
      duration_ms: 180_000,
      started_at: DateTime.utc_now() |> DateTime.truncate(:second),
      provider_ids: %{spotify: "sp-#{System.unique_integer([:positive])}"}
    }

    Repo.insert!(%RadioTrack{} |> RadioTrack.changeset(Map.merge(defaults, attrs)))
  end

  describe "execute/2" do
    test "returns tracks for a public radio on today (no params)" do
      streamer = public_streamer()
      insert_radio_track(streamer, %{name: "My Song"})

      assert {:reply, resp, _} = GetTracks.execute(%{username: streamer.username}, %Frame{})
      refute resp.isError
      data = decode(resp)
      assert [track] = data["tracks"]
      assert track["name"] == "My Song"
      assert track["artist"] == "Artist"
      assert Map.has_key?(track, "spotify_id")
      assert Map.has_key?(track, "started_at")
      assert data["date_from"] == Date.to_iso8601(Date.utc_today())
      assert data["date_to"] == Date.to_iso8601(Date.utc_today())
    end

    test "returns tracks for a specific date" do
      streamer = public_streamer()
      date = ~D[2026-01-15]
      started_at = DateTime.new!(date, ~T[12:00:00], "Etc/UTC")
      insert_radio_track(streamer, %{name: "Past Song", started_at: started_at})

      assert {:reply, resp, _} = GetTracks.execute(%{username: streamer.username, date_from: "2026-01-15"}, %Frame{})
      data = decode(resp)
      assert [track] = data["tracks"]
      assert track["name"] == "Past Song"
      assert data["date_from"] == "2026-01-15"
      assert data["date_to"] == "2026-01-15"
    end

    test "returns tracks across a date range" do
      streamer = public_streamer()
      insert_radio_track(streamer, %{name: "Day 1", started_at: ~U[2026-01-10 10:00:00Z]})
      insert_radio_track(streamer, %{name: "Day 2", started_at: ~U[2026-01-11 10:00:00Z]})
      insert_radio_track(streamer, %{name: "Day 3", started_at: ~U[2026-01-12 10:00:00Z]})

      assert {:reply, resp, _} =
               GetTracks.execute(
                 %{username: streamer.username, date_from: "2026-01-10", date_to: "2026-01-11"},
                 %Frame{}
               )

      data = decode(resp)
      assert length(data["tracks"]) == 2
      assert data["date_from"] == "2026-01-10"
      assert data["date_to"] == "2026-01-11"
      names = Enum.map(data["tracks"], & &1["name"])
      assert "Day 1" in names
      assert "Day 2" in names
    end

    test "date_to defaults to date_from when only date_from is given" do
      streamer = public_streamer()
      insert_radio_track(streamer, %{name: "Only Day", started_at: ~U[2026-03-01 10:00:00Z]})

      assert {:reply, resp, _} =
               GetTracks.execute(%{username: streamer.username, date_from: "2026-03-01"}, %Frame{})

      data = decode(resp)
      assert data["date_from"] == "2026-03-01"
      assert data["date_to"] == "2026-03-01"
      assert [%{"name" => "Only Day"}] = data["tracks"]
    end

    test "returns error when date_from is after date_to" do
      streamer = public_streamer()

      assert {:reply, resp, _} =
               GetTracks.execute(
                 %{username: streamer.username, date_from: "2026-01-15", date_to: "2026-01-10"},
                 %Frame{}
               )

      assert resp.isError == true
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "before or equal"
    end

    test "returns empty list when no tracks for that date" do
      streamer = public_streamer()

      assert {:reply, resp, _} =
               GetTracks.execute(%{username: streamer.username, date_from: "2020-01-01"}, %Frame{})

      data = decode(resp)
      assert data["tracks"] == []
    end

    test "returns error for unknown username" do
      assert {:reply, resp, _} = GetTracks.execute(%{username: "nobody-#{System.unique_integer()}"}, %Frame{})
      assert resp.isError == true
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "not found"
    end

    test "returns error for private radio" do
      user = user_fixture()
      {:ok, user} = User.edit_user_profile(user, %{radio_settings: %{visibility: :private}})

      assert {:reply, resp, _} = GetTracks.execute(%{username: user.username}, %Frame{})
      assert resp.isError == true
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "private"
    end

    test "returns error for invalid date format" do
      streamer = public_streamer()

      assert {:reply, resp, _} =
               GetTracks.execute(%{username: streamer.username, date_from: "not-a-date"}, %Frame{})

      assert resp.isError == true
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "Invalid date"
    end

    test "does not return tracks from other users" do
      streamer = public_streamer()
      other = user_fixture()
      insert_radio_track(other, %{name: "Other Song"})

      assert {:reply, resp, _} = GetTracks.execute(%{username: streamer.username}, %Frame{})
      data = decode(resp)
      assert data["tracks"] == []
    end
  end
end
