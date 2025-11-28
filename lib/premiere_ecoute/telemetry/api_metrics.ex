defmodule PremiereEcoute.Telemetry.ApiMetrics do
  @moduledoc """
  PromEx plugin for API telemetry metrics.

  Tracks API call counts and webhook event counts with detailed metadata including provider, HTTP method, URL path, and response status for monitoring external API usage.
  """

  use PromEx.Plugin

  @api_call [:premiere_ecoute, :apis, :api_call]
  @webhook_event [:premiere_ecoute, :apis, :webhook_event]

  @doc """
  Emits telemetry event for API call.

  Records API call metrics including provider, HTTP method, URL path, and response status code.
  """
  @spec api_call(atom(), {Req.Request.t(), Req.Response.t()}) :: :ok
  def api_call(provider, {%Req.Request{} = request, %Req.Response{} = response}) do
    :telemetry.execute(
      @api_call,
      %{},
      %{
        provider: provider,
        method: request.method,
        url: request.url.path,
        status: response.status
      }
    )
  end

  @doc """
  Emits telemetry event for webhook.

  Records webhook event metrics including provider and event type.
  """
  @spec webhook_event(atom(), atom()) :: :ok
  def webhook_event(provider, type) do
    :telemetry.execute(@webhook_event, %{}, %{provider: provider, type: type})
  end

  @impl true
  def event_metrics(_opts) do
    [
      Event.build(
        :premiere_ecoute_apis_twitch_calls,
        [
          counter(
            @api_call ++ [:count],
            event_name: @api_call,
            description: "The number of API calls",
            tags: [:provider, :method, :url, :status]
          )
        ]
      ),
      Event.build(
        :premiere_ecoute_apis_twitch_webhooks,
        [
          counter(
            @webhook_event ++ [:count],
            event_name: @webhook_event,
            description: "The number of webhook requests",
            tags: [:provider, :type]
          )
        ]
      )
    ]
  end
end
