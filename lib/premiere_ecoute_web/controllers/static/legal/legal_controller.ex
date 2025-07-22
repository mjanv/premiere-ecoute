defmodule PremiereEcouteWeb.Static.Legal.LegalController do
  use PremiereEcouteWeb, :controller

  alias PremiereEcouteWeb.Static.Legal

  def privacy(conn, _params) do
    render(conn, "document.html", document: Legal.document("privacy"))
  end

  def cookies(conn, _params) do
    render(conn, "document.html", document: Legal.document("cookies"))
  end

  def terms(conn, _params) do
    render(conn, "document.html", document: Legal.document("terms"))
  end

  def contact(conn, _params) do
    render(conn, "document.html", document: Legal.document("contact"))
  end
end
