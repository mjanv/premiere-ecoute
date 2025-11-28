defmodule PremiereEcouteWeb.Static.Changelog.ChangelogController do
  @moduledoc """
  Changelog controller.

  Serves changelog entries listing all release notes and individual changelog entry details.
  """

  use PremiereEcouteWeb, :controller

  alias PremiereEcouteWeb.Static.Changelog

  @doc """
  Renders changelog index page with all release notes.

  Displays complete list of changelog entries showing application version history and release notes.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html", changelog: Changelog.all_entries())
  end

  @doc """
  Renders individual changelog entry detail page.

  Displays detailed view of a specific changelog entry identified by its ID with full release notes and changes.
  """
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    render(conn, "entry.html", entry: Changelog.get_entry(id))
  end
end
