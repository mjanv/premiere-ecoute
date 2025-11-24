defmodule PremiereEcoute.Telemetry.PromEx do
  @moduledoc false

  use PromEx, otp_app: :premiere_ecoute

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      Plugins.Application,
      Plugins.Beam,
      {Plugins.Phoenix, router: PremiereEcouteWeb.Router, endpoint: PremiereEcouteWeb.Endpoint},
      Plugins.Ecto,
      Plugins.PhoenixLiveView,
      PremiereEcoute.Telemetry.ApiMetrics
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "grafanacloud-mjanv-prom",
      default_selected_interval: "15s"
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      {:prom_ex, "phoenix_live_view.json"},
      {:premiere_ecoute, "/dashboards/premiere_ecoute.json"}
    ]
  end
end
