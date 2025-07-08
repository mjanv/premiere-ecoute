defmodule PremiereEcoute.Telemetry.Apis.TwitchApiMetrics do
  @moduledoc false

  use PromEx.Plugin

  @webhook_event [:premiere_ecoute, :apis, :twitch_api, :webhook_received]

  def webhook_received(type), do: :telemetry.execute(@webhook_event, %{}, %{type: type})

  @impl true
  def event_metrics(_opts) do
    [
      Event.build(
        :premiere_ecoute_apis_twitch_api_webhooks,
        [
          counter(
            @webhook_event ++ [:count],
            event_name: @webhook_event,
            description: "The number of Twitch webhook requests",
            tags: [:message_type],
            tag_values: fn %{type: type} -> %{message_type: type} end
          )
        ]
      )
    ]
  end
end
