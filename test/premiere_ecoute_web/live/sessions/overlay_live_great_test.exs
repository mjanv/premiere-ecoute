defmodule PremiereEcouteWeb.Sessions.OverlayLiveGreatTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  # The overlay of a user without an active session still follows vote and score
  # events, which is enough to drive its visual states.
  setup do
    {:ok, user} =
      %{role: :streamer}
      |> user_fixture()
      |> PremiereEcoute.Accounts.edit_user_profile(%{widget_settings: %{color_primary: "#76ce66", color_secondary: "#ff2d55"}})

    {:ok, user: user}
  end

  defp overlay(conn, user, score) do
    {:ok, view, _html} = live(conn, ~p"/sessions/overlay/#{user.username}?score=#{score}")
    view
  end

  defp scores(view, viewer, streamer \\ nil) do
    send(view.pid, {:session_summary, %{viewer_score: viewer, streamer_score: streamer, track_id: 1}})
    render(view)
  end

  describe "regular state" do
    test "shows the textures with the user's colours, without the great layers", %{conn: conn, user: user} do
      view = overlay(conn, user, "viewer")
      send(view.pid, :vote_open)
      scores(view, 7.4)

      assert has_element?(view, "[data-overlay-root][data-primary='#76ce66'][data-secondary='#ff2d55']")
      assert has_element?(view, "div[style*='visibility: visible'] #overlay-texture[phx-hook='PaperTexture']")
      assert has_element?(view, "div[style*='visibility: visible'] #overlay-grain[phx-hook='HalftoneGrain']")
      refute has_element?(view, "#overlay-liquid")
      refute has_element?(view, "#overlay-film-grain")
      assert has_element?(view, "#overlay-progress[data-remaining='#d4d4cc']:not([data-shiny])")
    end
  end

  describe "great score" do
    test "paints the widget white under the liquid and film grain layers", %{conn: conn, user: user} do
      view = overlay(conn, user, "viewer")
      send(view.pid, :vote_open)
      scores(view, 9.8)

      assert has_element?(view, "#overlay-liquid[phx-hook='LiquidField'][style*='mix-blend-mode: multiply']")
      assert has_element?(view, "#overlay-film-grain[phx-hook='FilmGrain'][style*='mix-blend-mode: screen']")
      assert has_element?(view, "[data-overlay-root][style*='color: #ffffff']")
      assert has_element?(view, "#overlay-progress[data-shiny][data-played='#ffffff'][data-remaining='#5c5c5c']")
    end

    test "hides the regular textures but keeps them mounted", %{conn: conn, user: user} do
      view = overlay(conn, user, "viewer")
      send(view.pid, :vote_open)
      scores(view, 9.8)

      assert has_element?(view, "div[style*='visibility: hidden'] #overlay-texture")
      assert has_element?(view, "div[style*='visibility: hidden'] #overlay-grain")
    end

    test "keeps the user's own colours for the textures", %{conn: conn, user: user} do
      view = overlay(conn, user, "viewer")
      send(view.pid, :vote_open)
      scores(view, 9.8)

      assert has_element?(view, "[data-overlay-root][data-primary='#76ce66'][data-secondary='#ff2d55']")
    end

    test "goes back to the regular state when the score drops", %{conn: conn, user: user} do
      view = overlay(conn, user, "viewer")
      send(view.pid, :vote_open)
      scores(view, 9.8)
      scores(view, 9.1)

      refute has_element?(view, "#overlay-liquid")
      refute has_element?(view, "#overlay-progress[data-shiny]")
      assert has_element?(view, "div[style*='visibility: visible'] #overlay-texture")
    end

    test "ends when the vote closes", %{conn: conn, user: user} do
      view = overlay(conn, user, "viewer")
      send(view.pid, :vote_open)
      scores(view, 9.8)
      send(view.pid, :vote_close)
      render(view)

      refute has_element?(view, "#overlay-liquid")
    end

    test "follows the score shown by the overlay", %{conn: conn, user: user} do
      viewer = overlay(conn, user, "viewer")
      scores(viewer, 8.0, 10.0)
      refute has_element?(viewer, "#overlay-liquid")

      streamer = overlay(conn, user, "streamer")
      scores(streamer, 8.0, 10.0)
      assert has_element?(streamer, "#overlay-liquid")

      both = overlay(conn, user, "both")
      scores(both, 8.0, 10.0)
      assert has_element?(both, "#overlay-liquid")
    end

    test "never applies to the votes overlay", %{conn: conn, user: user} do
      view = overlay(conn, user, "votes")
      scores(view, 10.0, 10.0)

      refute has_element?(view, "#overlay-liquid")
    end
  end

  describe "score box swap key" do
    test "changes with the vote state and the content shown", %{conn: conn, user: user} do
      view = overlay(conn, user, "viewer")

      send(view.pid, :vote_open)
      render(view)
      assert has_element?(view, "#score-box-viewer[phx-hook='DitherSwap'][data-key='open:unlock']")

      scores(view, 7.4)
      assert has_element?(view, "#score-box-viewer[data-key='open:score']")

      send(view.pid, :vote_close)
      render(view)
      assert has_element?(view, "#score-box-viewer[data-key='closed:lock']")
    end

    test "stays the same when the score value changes", %{conn: conn, user: user} do
      view = overlay(conn, user, "viewer")
      send(view.pid, :vote_open)
      scores(view, 7.4)
      scores(view, 8.1)

      assert has_element?(view, "#score-box-viewer[data-key='open:score']")
    end
  end

  describe "hooks" do
    test "every hook used by the overlay is registered", %{conn: conn, user: user} do
      view = overlay(conn, user, "viewer")
      send(view.pid, :vote_open)
      html = scores(view, 9.8)
      registered = File.read!("assets/js/hooks/index.js")

      hooks =
        ~r/phx-hook="([^"]+)"/
        |> Regex.scan(html, capture: :all_but_first)
        |> List.flatten()
        |> Enum.uniq()

      assert "LiquidField" in hooks
      for hook <- hooks, do: assert(registered =~ ~r/\b#{hook}: #{hook}\b/, "#{hook} is not registered")
    end
  end

  describe "star field" do
    test "renders the star layer behind the widget content", %{conn: conn, user: user} do
      view = overlay(conn, user, "viewer")

      assert has_element?(view, "#overlay-stars[phx-hook='StarField'][style*='z-index: -1']")
      assert has_element?(view, "[data-overlay-root][style*='isolation: isolate']")
    end

    test "forwards cast votes to the star field", %{conn: conn, user: user} do
      view = overlay(conn, user, "viewer")

      send(view.pid, {:votes_cast, [0.2, 0.5, 1.0]})

      assert_push_event(view, "votes_cast", %{values: [0.2, 0.5, 1.0]})
    end
  end
end
