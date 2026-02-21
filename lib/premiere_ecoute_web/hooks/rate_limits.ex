defmodule PremiereEcouteWeb.Hooks.RateLimits do
  @moduledoc """
  LiveView hook for rate limit banners.

  Subscribes to RateLimitMonitor broadcasts and keeps the `rate_limited_apis`
  assign up to date so the layout banner reflects the current cache state
  without a page reload.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias PremiereEcoute.Apis.RateLimit.CircuitBreakerMonitor

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) :: {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(_, _params, _session, socket) do
    if connected?(socket) do
      PremiereEcoute.PubSub.subscribe(CircuitBreakerMonitor.topic())
    end

    socket =
      socket
      |> assign_new(:banners, fn -> current_apis() end)
      |> attach_hook(:rate_limits, :handle_info, &handle_rate_limits/2)

    {:cont, socket}
  end

  defp handle_rate_limits({:rate_limits, apis}, socket) do
    {:halt, assign(socket, :banners, apis)}
  end

  defp handle_rate_limits(_, socket), do: {:cont, socket}

  # AIDEV-NOTE: seeds initial state before the first broadcast arrives
  # Each banner is {api, message, expires_at} — mirrors RateLimitMonitor.apis/0
  defp current_apis do
    :rate_limits
    |> Cachex.stream!()
    |> Enum.flat_map(fn {:entry, key, value, modified, expiration} ->
      if value do
        expires_at = expiration && DateTime.from_unix!(modified + expiration, :millisecond)
        [{key, value, expires_at}]
      else
        []
      end
    end)
    |> Enum.sort_by(fn {key, _, _} -> key end)
  rescue
    _ -> []
  end
end
