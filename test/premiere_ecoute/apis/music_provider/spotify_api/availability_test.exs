defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.AvailabilityTest do
  # async: false so the mock stubs set in the test process are visible to the
  # Task.async_stream worker processes spawned by Availability.check/0 (global Mox mode).
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Availability
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApiMock

  describe "check/0" do
    test "reports :ok when every route succeeds" do
      SpotifyApiMock
      |> stub(:search_albums, fn _query -> {:ok, []} end)
      |> stub(:get_artist, fn _id -> {:ok, %{}} end)
      |> stub(:get_artist_albums, fn _id -> {:ok, []} end)
      |> stub(:get_single, fn _id -> {:ok, %{}} end)

      report = Availability.check()

      assert report.status == :ok
      assert %DateTime{} = report.checked_at

      assert report.checks == %{
               search: :ok,
               artists: :ok,
               artist_albums: :ok,
               tracks: :ok
             }
    end

    test "reports :down when every route fails" do
      SpotifyApiMock
      |> stub(:search_albums, fn _query -> {:error, "boom"} end)
      |> stub(:get_artist, fn _id -> {:error, "boom"} end)
      |> stub(:get_artist_albums, fn _id -> {:error, "boom"} end)
      |> stub(:get_single, fn _id -> {:error, "boom"} end)

      report = Availability.check()

      assert report.status == :down
      assert Enum.all?(report.checks, fn {_route, result} -> match?({:error, _}, result) end)
    end

    test "reports :degraded when only some routes fail" do
      SpotifyApiMock
      |> stub(:search_albums, fn _query -> {:ok, []} end)
      |> stub(:get_artist, fn _id -> {:error, "rate limited"} end)
      |> stub(:get_artist_albums, fn _id -> {:ok, []} end)
      |> stub(:get_single, fn _id -> {:ok, %{}} end)

      report = Availability.check()

      assert report.status == :degraded
      assert report.checks.search == :ok
      assert report.checks.artists == {:error, "rate limited"}
      assert report.checks.artist_albums == :ok
      assert report.checks.tracks == :ok
    end
  end
end
