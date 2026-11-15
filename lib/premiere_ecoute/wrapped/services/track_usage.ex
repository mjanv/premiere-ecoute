defmodule PremiereEcoute.Wrapped.Services.TrackUsage do
  @moduledoc """
  Records how a Wrapped is used, as events on the `wrapped_recap` stream of its viewer.
  """

  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Events.WrappedShared
  alias PremiereEcoute.Events.WrappedViewed
  alias PremiereEcoute.Wrapped.Recap

  @doc "Records that a viewer opened their Wrapped, and with which render."
  @spec viewed(Recap.t(), atom() | nil) :: :ok
  def viewed(%Recap{user_id: user_id, year: year}, render \\ nil),
    do: Store.append(%WrappedViewed{id: user_id, year: year, render: name(render)}, stream: "wrapped_recap")

  @doc "Records that a viewer shared their Wrapped, and from which render."
  @spec shared(Recap.t(), atom() | nil) :: :ok
  def shared(%Recap{user_id: user_id, year: year}, render \\ nil),
    do: Store.append(%WrappedShared{id: user_id, year: year, render: name(render)}, stream: "wrapped_recap")

  defp name(nil), do: nil
  defp name(render), do: to_string(render)
end
