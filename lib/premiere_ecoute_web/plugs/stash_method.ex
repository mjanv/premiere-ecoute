defmodule PremiereEcouteWeb.Plugs.StashMethod do
  @moduledoc """
  Stashes the original HTTP method in `conn.private` before `Plug.Head` rewrites HEAD to GET.

  Lets downstream controllers (e.g. podcast audio) answer HEAD requests with headers only —
  without fetching bytes or counting a download — which `Plug.Head` alone can't express.
  """

  def init(opts), do: opts

  def call(conn, _opts), do: Plug.Conn.put_private(conn, :original_method, conn.method)
end
