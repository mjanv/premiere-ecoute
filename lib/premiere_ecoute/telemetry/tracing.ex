defmodule PremiereEcoute.Telemetry.Tracing do
  @moduledoc """
  OpenTelemetry auto-instrumentation setup.

  Attaches the `opentelemetry_*` telemetry handlers once at boot:

    * `OpentelemetryBandit` — the HTTP server spans, which root every inbound request trace
    * `OpentelemetryPhoenix` — endpoint, router and LiveView spans, nested under the Bandit span
    * `OpentelemetryEcto` — a span per `PremiereEcoute.Repo` query

  These produce the surrounding spans; the domain spans that make a trace readable are created
  explicitly at the call sites (see `PremiereEcouteCore.Tracing` and
  `PremiereEcoute.Sessions.Scores.MessagePipeline`).

  Started as an optional child of `PremiereEcoute.Telemetry.Supervisor`, which means it does not run
  under `:test` — the test suite attaches its own handlers when it needs spans.
  """

  require Logger

  @repo_event_prefix [:premiere_ecoute, :repo]

  @doc """
  Attaches the OpenTelemetry telemetry handlers.

  Returns `:ok` even when a handler is already attached, so that a supervisor restart does not bring
  the telemetry tree down with it.
  """
  @spec setup() :: :ok
  def setup do
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)
    OpentelemetryEcto.setup(@repo_event_prefix)

    Logger.info("OpenTelemetry instrumentation attached")

    :ok
  rescue
    error ->
      Logger.warning("Cannot attach OpenTelemetry instrumentation due to: #{inspect(error)}")

      :ok
  end
end
