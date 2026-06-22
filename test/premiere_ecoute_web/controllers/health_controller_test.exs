defmodule PremiereEcouteWeb.HealthControllerTest do
  # async: false so stubs set here are visible to the Task.async_stream workers
  # spawned by Availability.check/0 (global Mox mode) and so the rate limiter's
  # ETS state from other tests doesn't bleed in via concurrent runs.
  use PremiereEcouteWeb.ConnCase, async: false

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApiMock

  setup do
    start_supervised(PremiereEcoute.Apis.RateLimit.RateLimiter)
    :ok
  end

  describe "GET /health" do
    test "returns ok status", %{conn: conn} do
      conn = get(conn, ~p"/health")

      assert %{"status" => "ok"} = json_response(conn, 200)
    end
  end

  describe "GET /health/spotify" do
    test "returns 200 when every Spotify route is healthy", %{conn: conn} do
      SpotifyApiMock
      |> stub(:search_albums, fn _query -> {:ok, []} end)
      |> stub(:get_artist, fn _id -> {:ok, %{}} end)
      |> stub(:get_artist_albums, fn _id -> {:ok, []} end)
      |> stub(:get_single, fn _id -> {:ok, %{}} end)

      conn = get(conn, ~p"/health/spotify")

      assert %{"status" => "ok"} = json_response(conn, 200)
    end

    test "returns 503 when every Spotify route fails", %{conn: conn} do
      SpotifyApiMock
      |> stub(:search_albums, fn _query -> {:error, "boom"} end)
      |> stub(:get_artist, fn _id -> {:error, "boom"} end)
      |> stub(:get_artist_albums, fn _id -> {:error, "boom"} end)
      |> stub(:get_single, fn _id -> {:error, "boom"} end)

      conn = get(conn, ~p"/health/spotify")

      assert %{"status" => "down"} = json_response(conn, 503)
    end

    test "rate limits repeated requests from the same IP", %{conn: conn} do
      SpotifyApiMock
      |> stub(:search_albums, fn _query -> {:ok, []} end)
      |> stub(:get_artist, fn _id -> {:ok, %{}} end)
      |> stub(:get_artist_albums, fn _id -> {:ok, []} end)
      |> stub(:get_single, fn _id -> {:ok, %{}} end)

      conn = %{conn | remote_ip: {10, 0, 4, :rand.uniform(254)}}

      for _ <- 1..6 do
        assert get(conn, ~p"/health/spotify").status == 200
      end

      denied = get(conn, ~p"/health/spotify")

      assert denied.status == 429
      assert get_resp_header(denied, "retry-after") == ["60"]
    end
  end
end
