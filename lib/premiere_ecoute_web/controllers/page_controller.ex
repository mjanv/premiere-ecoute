defmodule PremiereEcouteWeb.PageController do
  use PremiereEcouteWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
