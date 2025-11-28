defmodule PremiereEcouteWeb.Static.Legal.LegalController do
  @moduledoc """
  Legal documents controller.

  Serves static legal documents including privacy policy, cookie policy, terms of service, and contact information pages.
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcouteWeb.Static.Legal

  @doc """
  Renders privacy policy page.

  Displays the application's privacy policy document detailing data collection, usage, and protection practices.
  """
  @spec privacy(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def privacy(conn, _params), do: render(conn, "document.html", document: Legal.document(:privacy))

  @doc """
  Renders cookie policy page.

  Displays the cookie policy document explaining cookie usage, types, and user consent requirements.
  """
  @spec cookies(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def cookies(conn, _params), do: render(conn, "document.html", document: Legal.document(:cookies))

  @doc """
  Renders terms of service page.

  Displays the terms of service document outlining user rights, responsibilities, and usage conditions.
  """
  @spec terms(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def terms(conn, _params), do: render(conn, "document.html", document: Legal.document(:terms))

  @doc """
  Renders contact information page.

  Displays contact details and methods for reaching application support or administration.
  """
  @spec contact(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def contact(conn, _params), do: render(conn, "document.html", document: Legal.document(:contact))
end
