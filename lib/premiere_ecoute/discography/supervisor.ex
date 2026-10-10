defmodule PremiereEcoute.Discography.Supervisor do
  @moduledoc false

  use PremiereEcouteCore.Supervisor,
    children: [
      {Task.Supervisor, name: PremiereEcoute.Discography.TaskSupervisor}
    ]

  @doc """
  Maps `function` over `enumerable` in supervised tasks and returns the results of those that succeeded.
  """
  @spec async(Enumerable.t(), (term() -> term())) :: [term()]
  def async(enumerable, function) do
    PremiereEcoute.Discography.TaskSupervisor
    |> Task.Supervisor.async_stream(enumerable, function, timeout: 30_000)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, r} -> r end)
  end
end
