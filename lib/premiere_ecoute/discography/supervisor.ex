defmodule PremiereEcoute.Discography.Supervisor do
  @moduledoc false

  use PremiereEcouteCore.Supervisor,
    children: [
      {Task.Supervisor, name: PremiereEcoute.Discography.TaskSupervisor}
    ]

  def async(enumerable, function) do
    PremiereEcoute.Discography.TaskSupervisor
    |> Task.Supervisor.async_stream(enumerable, function)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, r} -> r end)
    |> Enum.into(%{})
  end
end
