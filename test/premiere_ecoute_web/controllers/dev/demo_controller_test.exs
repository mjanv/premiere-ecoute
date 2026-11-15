defmodule PremiereEcouteWeb.Dev.DemoControllerTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias PremiereEcouteWeb.Dev.DemoController

  describe "index/2" do
    test "lists the demos with a link to each", %{conn: conn} do
      body = conn |> DemoController.index(%{}) |> html_response(200)

      assert body =~ ~s(href="/dev/demos/liquid-type")
    end
  end

  describe "show/2" do
    test "serves a demo page", %{conn: conn} do
      body = conn |> DemoController.show(%{"name" => "liquid-type"}) |> html_response(200)

      assert body =~ "<title>Liquid type</title>"
    end

    test "returns 404 for an unknown demo", %{conn: conn} do
      assert conn |> DemoController.show(%{"name" => "unknown"}) |> response(404)
    end

    test "does not read files outside the demos directory", %{conn: conn} do
      assert conn |> DemoController.show(%{"name" => "../static/robots"}) |> response(404)
    end
  end
end
