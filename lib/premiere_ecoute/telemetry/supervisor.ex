defmodule PremiereEcoute.Telemetry.Supervisor do
  @moduledoc """
  Telemetry subservice.

  Manages PromEx for Prometheus metrics export.
  """

  use Supervisor

  @doc """
  Starts telemetry supervisor with PromEx metrics.

  Initializes supervisor process for PromEx Prometheus metrics exporter for application observability.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      PremiereEcoute.Telemetry.PromEx
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
