defmodule PremiereEcouteWeb.Wrapped.WrappedLiveTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Events.WrappedShared
  alias PremiereEcoute.Events.WrappedViewed
  alias PremiereEcoute.Wrapped
  alias PremiereEcoute.Wrapped.Recap

  @year Date.utc_today().year

  @cards [
    %{
      "type" => "year_in_music",
      "appearance" => %{"colors" => ["#112233"]},
      "preview" => nil,
      "data" => %{"albums" => 12, "minutes" => 540}
    },
    %{
      "type" => "recap",
      "appearance" => %{"colors" => []},
      "preview" => nil,
      "data" => %{
        "albums" => 12,
        "minutes" => 540,
        "top" => [
          %{"name" => "Blue Album", "artist" => "Artist A", "cover_url" => "https://i.scdn.co/image/a", "score" => 9.5},
          %{"name" => "Red Album", "artist" => "Artist B", "cover_url" => "https://i.scdn.co/image/b", "score" => 9.0},
          %{"name" => "Green <Album>", "artist" => "Artist C", "cover_url" => "https://i.scdn.co/image/c", "score" => 8.0}
        ]
      }
    }
  ]

  setup do
    PremiereEcouteCore.FeatureFlag.enable(:wrapped)
    :ok
  end

  defp recap_fixture(user, attrs \\ %{}) do
    {:ok, recap} =
      Recap.store(
        user.id,
        @year,
        Map.merge(
          %{
            cards: @cards,
            version: Recap.version(),
            computed_at: DateTime.utc_now(:second)
          },
          attrs
        )
      )

    recap
  end

  describe "own Wrapped" do
    test "asks visitors who are not logged in to sign in with Twitch, and brings them back", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/wrapped/#{@year}")

      assert html =~ "Sign in with Twitch to see it"
      assert has_element?(lv, ~s|a.wrapped-cta[href="/auth/twitch?role=viewer&return_to=%2Fwrapped%2F#{@year}"]|)
    end

    test "redirects while the feature is disabled", %{conn: conn} do
      PremiereEcouteCore.FeatureFlag.disable(:wrapped)

      assert {:error, {:live_redirect, %{to: "/home"}}} = conn |> log_in_user(user_fixture()) |> live(~p"/wrapped/#{@year}")
    end

    test "redirects for a year without Wrapped", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/"}}} = conn |> log_in_user(user_fixture()) |> live(~p"/wrapped/2020")
    end

    test "plays the stored cards", %{conn: conn} do
      user = user_fixture(%{twitch: %{user_id: "viewer1"}})
      recap = recap_fixture(user)

      {:ok, lv, html} = conn |> log_in_user(user) |> live(~p"/wrapped/#{@year}")

      assert has_element?(lv, "#wrapped-player[phx-hook=WrappedPlayer]")
      assert has_element?(lv, "[data-card].wrapped-year-in-music[data-colors='[\"#112233\"]']")
      assert has_element?(lv, "[data-card].wrapped-recap [data-share]")
      assert html =~ "Blue Album"
      assert html =~ "/wrapped/#{@year}/s/#{recap.share_token}"
    end

    test "plays every kind of card", %{conn: conn} do
      user = user_fixture(%{twitch: %{user_id: "viewer1"}})
      album = %{"name" => "Blue Album", "artist" => "Artist A", "cover_url" => "https://i.scdn.co/image/a", "score" => 9.5}
      track = %{"name" => "Blue Song", "album" => "Blue Album", "artist" => "Artist A", "cover_url" => nil, "score" => 10.0}

      cards = [
        %{"type" => "your_months", "data" => %{"months" => [0, 1, 0, 0, 3, 0, 0, 0, 0, 0, 1, 0], "busiest" => 5}},
        %{
          "type" => "your_rooms",
          "data" => %{"rooms" => [%{"name" => "ana", "sessions" => 3}, %{"name" => "ben", "sessions" => 1}]}
        },
        %{"type" => "first_vote", "data" => %{"album" => album, "date" => "#{@year}-03-12"}},
        %{"type" => "top_album", "data" => %{"album" => album}},
        %{"type" => "next_albums", "data" => %{"albums" => [album, album]}},
        %{"type" => "top_track", "data" => %{"track" => track}},
        %{"type" => "next_tracks", "data" => %{"tracks" => [track, track]}},
        %{"type" => "top_single", "data" => %{"single" => %{album | "name" => "Blue Single"}}},
        %{"type" => "retired_card"}
      ]

      recap_fixture(user, %{cards: cards})

      {:ok, lv, html} = conn |> log_in_user(user) |> live(~p"/wrapped/#{@year}")

      assert has_element?(lv, ".wrapped-your-months .is-busiest", "3")
      assert has_element?(lv, ".wrapped-your-rooms li", "3 sessions")
      assert has_element?(lv, ".wrapped-first-vote .wrapped-date", "12 March")
      assert has_element?(lv, ".wrapped-top-album .wrapped-hero-score", "9.5")
      assert has_element?(lv, ".wrapped-next-albums li:nth-child(2)")
      assert has_element?(lv, ".wrapped-top-track", "Blue Song")
      assert has_element?(lv, ".wrapped-next-tracks li:nth-child(2)")
      assert has_element?(lv, ".wrapped-top-single", "Blue Single")
      assert has_element?(lv, "[data-start] .wrapped-lead")
      assert html =~ "May"
    end

    test "records views and shares", %{conn: conn} do
      user = user_fixture(%{twitch: %{user_id: "viewer1"}})
      recap_fixture(user)
      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/wrapped/#{@year}")

      render_hook(lv, "started", %{})
      render_hook(lv, "shared", %{})

      assert [%WrappedViewed{render: "classic"}, %WrappedShared{render: "classic"}] = Store.read("wrapped_recap-#{user.id}")
    end

    test "records nothing while there is no recap to play", %{conn: conn} do
      user = user_fixture(%{twitch: %{user_id: "viewer1"}})
      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/wrapped/#{@year}")

      render_hook(lv, "started", %{})
      render_hook(lv, "unknown", %{})

      assert Store.read("wrapped_recap-#{user.id}") == []
    end

    test "sends the previews of the cards to the player", %{conn: conn} do
      user = user_fixture(%{twitch: %{user_id: "viewer1"}})
      recap_fixture(user)

      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/wrapped/#{@year}")

      assert_push_event lv, "wrapped:previews", %{urls: [nil, nil]}
    end

    test "redirects for a year that is not a number", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/"}}} = conn |> log_in_user(user_fixture()) |> live("/wrapped/abc")
    end

    test "shows a waiting screen before the page is live", %{conn: conn} do
      user = user_fixture(%{twitch: %{user_id: "viewer1"}})

      html = conn |> log_in_user(user) |> get(~p"/wrapped/#{@year}") |> html_response(200)

      assert html =~ "Putting your year together"
      refute Wrapped.get_recap(user, @year)
    end

    test "recomputes a recap stored with another version", %{conn: conn} do
      user = user_fixture(%{twitch: %{user_id: "viewer1"}})
      recap_fixture(user, %{version: Recap.version() - 1})

      {:ok, lv, html} = conn |> log_in_user(user) |> live(~p"/wrapped/#{@year}")

      assert html =~ "Not enough albums"
      assert has_element?(lv, "a[href='/home']")
      assert %Recap{cards: []} = Wrapped.get_recap(user, @year)
    end

    test "ignores a computed recap once cards are playing, and unrelated messages", %{conn: conn} do
      user = user_fixture(%{twitch: %{user_id: "viewer1"}})
      recap = recap_fixture(user)
      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/wrapped/#{@year}")

      send(lv.pid, {:wrapped_computed, %{recap | cards: []}})
      send(lv.pid, :unrelated)

      assert render(lv) =~ "Blue Album"
    end

    test "asks users without Twitch to link their account", %{conn: conn} do
      {:ok, lv, _html} = conn |> log_in_user(user_fixture()) |> live(~p"/wrapped/#{@year}")

      assert has_element?(lv, "a[href='/auth/twitch']")
    end

    test "computes a missing recap and tells when there is too little to show", %{conn: conn} do
      user = user_fixture(%{twitch: %{user_id: "viewer1"}})

      {:ok, _lv, html} = conn |> log_in_user(user) |> live(~p"/wrapped/#{@year}")

      assert %Recap{cards: []} = Wrapped.get_recap(user, @year)
      assert html =~ "Not enough albums"
    end

    test "shows the cards as soon as the recap is computed", %{conn: conn} do
      user = user_fixture(%{twitch: %{user_id: "viewer1"}})
      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/wrapped/#{@year}")
      :sys.replace_state(lv.pid, fn state -> put_in(state.socket.assigns.state, :waiting) end)

      send(lv.pid, {:wrapped_computed, recap_fixture(user)})

      assert render(lv) =~ "Blue Album"
    end
  end

  describe "renders" do
    alias PremiereEcouteCore.FeatureFlag
    alias PremiereEcouteWeb.Wrapped.Renders
    alias PremiereEcouteWeb.Wrapped.Renders.Render
    alias PremiereEcouteWeb.Wrapped.Stories

    # Adds a second render for the test. Other tests keep the default render, which stays first.
    setup do
      shader = %Render{
        id: :"shader#{System.unique_integer([:positive])}",
        name: "Shader",
        hook: "WrappedPlayerShader",
        component: &Stories.stories/1
      }

      Application.put_env(:premiere_ecoute, Renders, renders: Renders.built_in() ++ [shader])
      on_exit(fn -> Application.delete_env(:premiere_ecoute, Renders) end)

      {:ok, shader: shader, user: user_fixture(%{twitch: %{user_id: "viewer1"}})}
    end

    test "plays the default render", %{conn: conn, user: user} do
      recap_fixture(user)

      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/wrapped/#{@year}")

      assert has_element?(lv, "#wrapped-player[phx-hook=WrappedPlayer][data-render=classic]")
    end

    test "plays the render assigned to the viewer and records it", %{conn: conn, user: user, shader: shader} do
      recap_fixture(user)
      FeatureFlag.enable(Renders.flag(shader), for_actor: user)

      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/wrapped/#{@year}")
      render_hook(lv, "started", %{})

      assert has_element?(lv, "#wrapped-player[phx-hook=WrappedPlayerShader][data-render=#{shader.id}]")
      assert [%WrappedViewed{render: render}] = Store.read("wrapped_recap-#{user.id}")
      assert render == Atom.to_string(shader.id)
    end

    test "ignores the render parameter of a viewer", %{conn: conn, user: user, shader: shader} do
      recap_fixture(user)

      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/wrapped/#{@year}?render=#{shader.id}")

      assert has_element?(lv, "#wrapped-player[data-render=classic]")
    end

    test "lets an admin pick a render with the render parameter", %{conn: conn, shader: shader} do
      admin = user_fixture(%{role: :admin, twitch: %{user_id: "admin1"}})
      recap_fixture(admin)

      {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/wrapped/#{@year}?render=#{shader.id}")
      {:ok, unknown, _html} = conn |> log_in_user(admin) |> live(~p"/wrapped/#{@year}?render=unknown")

      assert has_element?(lv, "#wrapped-player[data-render=#{shader.id}]")
      assert has_element?(unknown, "#wrapped-player[data-render=classic]")
    end

    test "replays a shared Wrapped with the render of its owner, whoever visits", %{conn: conn, user: user, shader: shader} do
      recap = recap_fixture(user)
      FeatureFlag.enable(Renders.flag(shader), for_actor: user)

      {:ok, lv, _html} = live(conn, ~p"/wrapped/#{@year}/s/#{recap.share_token}?render=classic")

      assert has_element?(lv, "#wrapped-player[data-render=#{shader.id}]")
    end
  end

  describe "shared Wrapped" do
    test "replays the public cards without login", %{conn: conn} do
      user = user_fixture()
      recap = recap_fixture(user, %{cards: Enum.take(@cards, 1)})

      {:ok, lv, html} = live(conn, ~p"/wrapped/#{@year}/s/#{recap.share_token}")

      assert has_element?(lv, "[data-card].wrapped-year-in-music")
      refute has_element?(lv, "[data-card].wrapped-recap")
      refute has_element?(lv, "[data-share]")
      assert html =~ user.username
    end

    test "names its owner in the page title and links the share card for previews", %{conn: conn} do
      user = user_fixture()
      recap = recap_fixture(user)

      html = conn |> get(~p"/wrapped/#{@year}/s/#{recap.share_token}") |> html_response(200)

      assert html =~ "#{user.username}&#39;s Wrapped #{@year}"
      assert html =~ "/wrapped/#{@year}/s/#{recap.share_token}/card.svg"
    end

    test "records neither views nor shares", %{conn: conn} do
      user = user_fixture()
      recap = recap_fixture(user)
      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/wrapped/#{@year}/s/#{recap.share_token}")

      render_hook(lv, "started", %{})
      render_hook(lv, "shared", %{})

      assert Store.read("wrapped_recap-#{user.id}") == []
    end

    # Pins current behaviour: a shared replay does not depend on the :wrapped feature flag
    test "is served while the feature is disabled", %{conn: conn} do
      PremiereEcouteCore.FeatureFlag.disable(:wrapped)
      recap = recap_fixture(user_fixture())

      assert {:ok, _lv, _html} = live(conn, ~p"/wrapped/#{@year}/s/#{recap.share_token}")
    end

    test "redirects for an unknown token", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/wrapped/#{@year}/s/unknown")
    end

    test "redirects for a recap without card, of another year or of another version", %{conn: conn} do
      empty = recap_fixture(user_fixture(), %{cards: []})
      recap = recap_fixture(user_fixture())
      old = recap_fixture(user_fixture(), %{version: Recap.version() - 1})

      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/wrapped/#{@year}/s/#{empty.share_token}")
      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/wrapped/#{@year - 1}/s/#{recap.share_token}")
      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/wrapped/#{@year}/s/#{old.share_token}")
    end
  end
end
