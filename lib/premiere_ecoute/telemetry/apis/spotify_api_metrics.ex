defmodule PremiereEcoute.Telemetry.Apis.SpotifyApiMetrics do
  @moduledoc false

  use PromEx.Plugin

  @api_event [:premiere_ecoute, :apis, :spotify, :api_called]

  def api_called({%Req.Request{} = request, %Req.Response{} = response}) do
    :telemetry.execute(@api_event, %{}, %{
      method: request.method,
      url: request.url.path,
      status: response.status
    })
  end

  @impl true
  def event_metrics(_opts) do
    [
      Event.build(
        :premiere_ecoute_apis_spotify_api_calls,
        [
          counter(
            @api_event ++ [:count],
            event_name: @api_event,
            description: "The number of Spotify API calls",
            tags: [:method, :url, :status]
          )
        ]
      )
    ]
  end
end
