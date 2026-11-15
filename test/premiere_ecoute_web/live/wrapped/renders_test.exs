defmodule PremiereEcouteWeb.Wrapped.RendersTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest

  alias PremiereEcouteCore.FeatureFlag
  alias PremiereEcouteWeb.Wrapped.Renders
  alias PremiereEcouteWeb.Wrapped.Renders.Render
  alias PremiereEcouteWeb.Wrapped.Stories

  # Three renders, as if two more had been developed. Their flags are unique to each test: flags are shared between tests.
  defp renders do
    n = System.unique_integer([:positive])

    [
      %Render{id: :classic, name: "Classic", hook: "WrappedPlayer", component: &Stories.stories/1},
      %Render{id: :"shader#{n}", name: "Shader", hook: "WrappedPlayerShader", component: &Stories.stories/1},
      %Render{id: :"still#{n}", name: "Still", hook: "WrappedPlayerStill", component: fn assigns -> ~H"<p>still {@year}</p>" end}
    ]
  end

  describe "built_in/0 and all/0" do
    test "ship the classic render as the default one" do
      assert [%Render{id: :classic, hook: "WrappedPlayer"} | _] = Renders.built_in()
      assert hd(Renders.all()) == hd(Renders.built_in())
      assert Renders.default() == hd(Renders.built_in())
    end

    test "give every render its own id and a registered hook" do
      renders = Renders.built_in()
      hooks = File.read!("assets/js/wrapped/index.js")

      assert renders |> Enum.map(& &1.id) |> Enum.uniq() |> length() == length(renders)
      for render <- renders, do: assert(hooks =~ ~r/\b#{render.hook}\b/)
    end
  end

  describe "built-in renders" do
    test "include the pixel render, drawn by its own component" do
      assert %Render{id: :pixel, hook: "WrappedPlayerPixel", component: component} = Renders.get(:pixel, Renders.built_in())

      html = render_component(component, year: 2026, cards: [], owner: nil, share_url: nil, exit_to: "/")

      assert html =~ ~s(phx-hook="WrappedPlayerPixel")
      assert html =~ "data-screen"
    end
  end

  describe "get/2" do
    test "finds a render from an atom or from the text of a URL parameter" do
      [classic, shader, _] = renders = renders()

      assert Renders.get(:classic, renders) == classic
      assert Renders.get("classic", renders) == classic
      assert Renders.get(Atom.to_string(shader.id), renders) == shader
    end

    test "finds nothing for an unknown id" do
      assert Renders.get("unknown", renders()) == nil
      assert Renders.get(nil, renders()) == nil
      assert Renders.get("", renders()) == nil
    end
  end

  describe "flag/1" do
    test "names the feature flag of a render" do
      assert Renders.flag(Renders.default()) == :wrapped_render_classic
    end
  end

  describe "assigned/2" do
    test "gives the default render to a visitor and to a user without flag" do
      [classic | _] = renders = renders()

      assert Renders.assigned(nil, renders) == classic
      assert Renders.assigned(user_fixture(), renders) == classic
    end

    test "gives a render to the users its flag is enabled for" do
      [classic, shader, _] = renders = renders()
      [chosen, other] = for _ <- 1..2, do: user_fixture()
      FeatureFlag.enable(Renders.flag(shader), for_actor: chosen)

      assert Renders.assigned(chosen, renders) == shader
      assert Renders.assigned(other, renders) == classic
    end

    test "gives the first enabled render when several flags are enabled" do
      [_, shader, still] = renders = renders()
      user = user_fixture()
      FeatureFlag.enable(Renders.flag(still), for_actor: user)

      assert Renders.assigned(user, renders) == still

      FeatureFlag.enable(Renders.flag(shader), for_actor: user)

      assert Renders.assigned(user, renders) == shader
    end

    test "never assigns through the flag of the default render" do
      [classic, shader, _] = renders = renders()
      user = user_fixture()
      FeatureFlag.enable(Renders.flag(shader), for_actor: user)
      FeatureFlag.enable(Renders.flag(classic), for_actor: user)

      assert Renders.assigned(user, renders) == shader
    end
  end

  describe "select/2" do
    test "plays the render of the URL parameter where it may be overridden" do
      [classic, shader, still] = renders = renders()
      user = user_fixture()
      FeatureFlag.enable(Renders.flag(shader), for_actor: user)

      assert Renders.select([param: Atom.to_string(still.id), user: user, override?: true], renders) == still
      assert Renders.select([param: "classic", user: user, override?: true], renders) == classic
    end

    test "ignores the URL parameter elsewhere" do
      [classic, shader, still] = renders = renders()
      user = user_fixture()

      assert Renders.select([param: Atom.to_string(still.id), user: user, override?: false], renders) == classic
      assert Renders.select([param: Atom.to_string(still.id), user: user], renders) == classic

      FeatureFlag.enable(Renders.flag(shader), for_actor: user)

      assert Renders.select([param: Atom.to_string(still.id), user: user, override?: false], renders) == shader
    end

    test "falls back on the assigned render for an unknown or a missing parameter" do
      [classic, shader, _] = renders = renders()
      user = user_fixture()
      FeatureFlag.enable(Renders.flag(shader), for_actor: user)

      assert Renders.select([param: "unknown", user: user, override?: true], renders) == shader
      assert Renders.select([param: nil, user: user, override?: true], renders) == shader
      assert Renders.select([param: "unknown", user: nil, override?: true], renders) == classic
      assert Renders.select([], renders) == classic
    end
  end

  describe "player/1" do
    test "renders the cards with the component and the hook of the render" do
      [classic, shader, still] = renders()
      assigns = [year: 2026, cards: [], owner: nil, share_url: nil, exit_to: "/"]

      assert render_component(&Renders.player/1, [render: classic] ++ assigns) =~ ~s(phx-hook="WrappedPlayer")
      assert render_component(&Renders.player/1, [render: shader] ++ assigns) =~ ~s(phx-hook="WrappedPlayerShader")
      assert render_component(&Renders.player/1, [render: shader] ++ assigns) =~ ~s(data-render="#{shader.id}")
      assert render_component(&Renders.player/1, [render: still] ++ assigns) =~ "<p>still 2026</p>"
    end
  end
end
