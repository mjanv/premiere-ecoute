defmodule PremiereEcoute.Telemetry.Apis.TwitchApiMetrics do
  @moduledoc false

  use PromEx.Plugin

  @api_event [:premiere_ecoute, :apis, :twitch_api, :api_called]
  @webhook_event [:premiere_ecoute, :apis, :twitch_api, :webhook_received]

  def api_called({%Req.Request{} = request, %Req.Response{} = response}) do
    :telemetry.execute(@api_event, %{}, %{
      method: request.method,
      url: request.url.path,
      status: response.status
    })
  end

  def webhook_received(type) do
    :telemetry.execute(@webhook_event, %{}, %{type: type})
  end

  @impl true
  def event_metrics(_opts) do
    [
      Event.build(
        :premiere_ecoute_apis_twitch_api_api_calls,
        [
          counter(
            @api_event ++ [:count],
            event_name: @api_event,
            description: "The number of Twitch API calls",
            tags: [:method, :url, :status]
          )
        ]
      ),
      Event.build(
        :premiere_ecoute_apis_twitch_api_webhooks,
        [
          counter(
            @webhook_event ++ [:count],
            event_name: @webhook_event,
            description: "The number of Twitch webhook requests",
            tags: [:type]
          )
        ]
      )
    ]
  end
end
