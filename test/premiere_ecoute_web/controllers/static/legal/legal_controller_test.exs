defmodule PremiereEcouteWeb.Static.Legal.LegalControllerTest do
  use PremiereEcouteWeb.ConnCase, async: true

  test "GET /legal/podcast renders the podcast content policy", %{conn: conn} do
    conn = get(conn, ~p"/legal/podcast")
    assert html_response(conn, 200) =~ "Politique de contenu des podcasts"
  end
end
