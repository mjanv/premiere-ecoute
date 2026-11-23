defmodule PremiereEcouteWeb.Sessions.OverlayTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcouteWeb.Sessions.Overlay

  defp summary(scores), do: AsyncResult.ok(scores)

  describe "great?/2" do
    test "is true for a viewer score at or above 9.75" do
      assert Overlay.great?(summary(%{viewer_score: 9.75}), :viewer)
      assert Overlay.great?(summary(%{viewer_score: 10.0}), :viewer)
      refute Overlay.great?(summary(%{viewer_score: 9.7}), :viewer)
    end

    test "reads string keys, as in stored report summaries" do
      assert Overlay.great?(summary(%{"viewer_score" => 9.8}), :viewer)
      assert Overlay.great?(summary(%{"streamer_score" => 10}), :streamer)
    end

    test "only looks at the score shown" do
      scores = summary(%{viewer_score: 8.0, streamer_score: 10.0})

      assert Overlay.great?(scores, :streamer)
      refute Overlay.great?(scores, :viewer)
    end

    test "is true in both mode when either score is great" do
      assert Overlay.great?(summary(%{viewer_score: 9.8, streamer_score: 6.0}), :both)
      assert Overlay.great?(summary(%{viewer_score: 6.0, streamer_score: 10.0}), :both)
      refute Overlay.great?(summary(%{viewer_score: 9.7, streamer_score: 9.0}), :both)
    end

    test "is false without a score, while loading, and for the player and votes overlays" do
      refute Overlay.great?(summary(%{viewer_score: nil, streamer_score: nil}), :viewer)
      refute Overlay.great?(AsyncResult.loading(), :viewer)
      refute Overlay.great?(summary(%{viewer_score: 10.0, streamer_score: 10.0}), :player)
      refute Overlay.great?(summary(%{viewer_score: 10.0, streamer_score: 10.0}), :votes)
    end
  end

  describe "paint/1" do
    defp paint(scores, widget_state) do
      assigns = %{summary: summary(scores), widget_state: widget_state}

      ~H"""
      <Overlay.paint
        :let={p}
        primary="#123456"
        secondary="#abcdef"
        summary={@summary}
        score={:viewer}
        widget_state={@widget_state}
      >
        {p.great}|{p.primary}|{p.secondary}|{p.text}
      </Overlay.paint>
      """
      |> rendered_to_string()
      |> String.trim()
    end

    test "yields the user's colours for a regular score" do
      assert paint(%{viewer_score: 7.4}, :open) == "false|#123456|#abcdef|#123456"
    end

    test "yields white for every colour for a great score" do
      assert paint(%{viewer_score: 9.8}, :open) == "true|#ffffff|#ffffff|#ffffff"
    end

    test "keeps the text colour of the vote state" do
      assert paint(%{viewer_score: nil}, :closed) == "false|#123456|#abcdef|#000000"
    end
  end

  describe "layer/1" do
    test "renders a full-widget canvas driven by a hook, blended over the widget" do
      assigns = %{}

      html = rendered_to_string(~H|<Overlay.layer id="overlay-liquid" hook="LiquidField" blend="multiply" />|)

      assert html =~ ~s(id="overlay-liquid")
      assert html =~ ~s(phx-hook="LiquidField")
      assert html =~ ~s(phx-update="ignore")
      assert html =~ "mix-blend-mode: multiply"
      assert html =~ "pointer-events: none"
    end
  end
end
