defmodule PremiereEcouteWeb.Static.Legal.LegalController do
  use PremiereEcouteWeb, :controller

  def privacy(conn, _params) do
    render(conn, "privacy.html")
  end

  def cookies(conn, _params) do
    render(conn, "cookies.html")
  end

  def terms(conn, _params) do
    render(conn, "terms.html")
  end

  def contact(conn, _params) do
    locale = Gettext.get_locale(PremiereEcouteWeb.Gettext)
    render(conn, "contact_#{locale}.html")
  end
end
