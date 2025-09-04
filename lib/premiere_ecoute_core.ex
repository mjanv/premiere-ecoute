defmodule PremiereEcouteCore do
  @moduledoc """
  Core system facade module

  Provides centralized access to the application's command and event processing systems. This module acts as the primary interface for executing commands through the command bus and dispatching events through the event bus.
  """

  use Boundary,
    deps: [],
    exports: [
      Aggregate,
      Aggregate.Entity,
      Aggregate.Object,
      Api,
      Cache,
      CommandBus.Handler,
      Date,
      Duration,
      Event,
      EventBus.Handler,
      FeatureFlag,
      GoofyWords,
      Search,
      Subscriber,
      Utils,
      Worker
    ]

  alias PremiereEcouteCore.BroadwayProducer
  alias PremiereEcouteCore.CommandBus
  alias PremiereEcouteCore.EventBus

  defdelegate apply(command), to: CommandBus
  defdelegate dispatch(event), to: EventBus
  defdelegate publish(pipeline, message), to: BroadwayProducer
end
