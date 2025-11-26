defmodule PremiereEcouteWeb.Static.Legal.LegalController do
  @moduledoc """
  Legal documents controller.

  Serves static legal documents including privacy policy, cookie policy, terms of service, and contact information pages.
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcouteWeb.Static.Legal

  def privacy(conn, _params), do: render(conn, "document.html", document: Legal.document(:privacy))
  def cookies(conn, _params), do: render(conn, "document.html", document: Legal.document(:cookies))
  def terms(conn, _params), do: render(conn, "document.html", document: Legal.document(:terms))
  def contact(conn, _params), do: render(conn, "document.html", document: Legal.document(:contact))
end
