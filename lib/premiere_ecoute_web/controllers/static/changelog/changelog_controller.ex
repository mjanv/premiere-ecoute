defmodule PremiereEcouteWeb.Static.ChangelogController do
  use PremiereEcouteWeb, :controller

  alias PremiereEcouteWeb.Static.Changelog

  def index(conn, _params) do
    render(conn, "index.html", changelog: Changelog.all_entries())
  end

  def show(conn, %{"id" => id}) do
    render(conn, "show.html", entry: Changelog.get_entry(id))
  end
end
