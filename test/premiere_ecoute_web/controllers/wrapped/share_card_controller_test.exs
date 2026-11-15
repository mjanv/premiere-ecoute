defmodule PremiereEcouteWeb.Wrapped.ShareCardControllerTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import PremiereEcoute.Wrapped.WrappedFixtures

  alias PremiereEcoute.Wrapped.Recap
  alias PremiereEcouteWeb.Wrapped.ShareCardController

  @year Date.utc_today().year

  defp album(name, attrs \\ %{}),
    do: Map.merge(%{"name" => name, "artist" => "Artist", "cover_url" => nil, "score" => 9.5}, attrs)

  defp recap_card(data \\ %{}, appearance \\ %{"colors" => ["#112233", "#445566", "#778899"]}) do
    %{
      "type" => "recap",
      "appearance" => appearance,
      "preview" => nil,
      "data" =>
        Map.merge(
          %{"top" => [album("Blue Album"), album("Red Album"), album("Green Album")], "albums" => 12, "minutes" => 540},
          data
        )
    }
  end

  describe "GET /wrapped/:year/s/:share_token/card.svg" do
    test "renders the recap card as a cacheable SVG", %{conn: conn} do
      recap = recap_fixture(user_fixture(), @year, %{cards: [%{"type" => "year_in_music"}, recap_card()]})

      conn = get(conn, ~p"/wrapped/#{@year}/s/#{recap.share_token}/card.svg")

      assert response_content_type(conn, :svg) =~ "image/svg+xml"
      assert get_resp_header(conn, "cache-control") == ["public, max-age=86400"]
      assert response(conn, 200) =~ "Blue Album"
      assert response(conn, 200) =~ ">#{@year}<"
    end

    test "returns 404 for a recap without recap card", %{conn: conn} do
      recap = recap_fixture(user_fixture(), @year, %{cards: [%{"type" => "year_in_music"}]})
      empty = recap_fixture(user_fixture(), @year)

      assert conn |> get(~p"/wrapped/#{@year}/s/#{recap.share_token}/card.svg") |> response(404)
      assert conn |> get(~p"/wrapped/#{@year}/s/#{empty.share_token}/card.svg") |> response(404)
    end

    test "returns 404 for an unknown token, another year or a year that is not a number", %{conn: conn} do
      recap = recap_fixture(user_fixture(), @year, %{cards: [recap_card()]})

      assert conn |> get(~p"/wrapped/#{@year}/s/unknown/card.svg") |> response(404)
      assert conn |> get(~p"/wrapped/#{@year - 1}/s/#{recap.share_token}/card.svg") |> response(404)
      assert conn |> get("/wrapped/abc/s/#{recap.share_token}/card.svg") |> response(404)
    end

    test "returns 404 for a recap computed with another version", %{conn: conn} do
      recap = recap_fixture(user_fixture(), @year, %{cards: [recap_card()], version: Recap.version() - 1})

      assert conn |> get(~p"/wrapped/#{@year}/s/#{recap.share_token}/card.svg") |> response(404)
    end
  end

  describe "svg/2" do
    test "lists the top albums with their rank, artist and score" do
      svg = ShareCardController.svg(recap_card(%{"top" => [album("Blue Album", %{"score" => 9})]}), 2026)

      assert svg =~ ">2026<"
      assert svg =~ ">Blue Album<"
      assert svg =~ ">Artist<"
      assert svg =~ ">9.0<"
      assert svg =~ ">12<"
      assert svg =~ ">540<"
    end

    test "tints the card with the colours of the cover" do
      svg = ShareCardController.svg(recap_card(), 2026)

      assert svg =~ ~s(stop-color="#112233")
      assert svg =~ ~s(stop-color="#445566")
      assert svg =~ ~s(stop-color="#778899")
    end

    test "completes missing colours with the default ones" do
      one = ShareCardController.svg(recap_card(%{}, %{"colors" => ["#112233"]}), 2026)
      none = ShareCardController.svg(Map.delete(recap_card(), "appearance"), 2026)

      assert one =~ ~r/stop-color="#112233".*stop-color="#6d28d9".*stop-color="#db2777"/s
      assert none =~ ~r/stop-color="#6d28d9".*stop-color="#db2777".*stop-color="#1e1b4b"/s
    end

    test "leaves the minutes out when there are none" do
      svg = ShareCardController.svg(recap_card(%{"minutes" => 0}), 2026)

      refute svg =~ "minute"
      assert svg =~ "albums"
    end

    test "uses the singular for one album and one minute" do
      svg = ShareCardController.svg(recap_card(%{"albums" => 1, "minutes" => 1}), 2026)

      assert svg =~ ">album<"
      assert svg =~ ">minute<"
    end

    test "shortens long names and escapes them" do
      long = String.duplicate("a", 40)

      svg =
        ShareCardController.svg(
          recap_card(%{"top" => [album(long), album("Rock & <Roll>"), album("No artist", %{"artist" => nil})]}),
          2026
        )

      assert svg =~ ">#{String.duplicate("a", 23)}…<"
      refute svg =~ long
      assert svg =~ "Rock &amp; &lt;Roll&gt;"
      refute svg =~ "<Roll>"
    end
  end
end
