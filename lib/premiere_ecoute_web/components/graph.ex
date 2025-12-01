defmodule PremiereEcouteWeb.Components.Live.Graph do
  @moduledoc false

  use PremiereEcouteWeb, :live_component

  require VegaLite, as: Vl

  @impl true
  def update(%{id: id, title: title, data: data, x: x, y: y}, socket) do
    socket
    |> assign(id: id)
    |> push_event("vega_lite:#{id}:init", %{"spec" => bar(data, title, x, y)})
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="w-full h-full min-h-[400px]"
      phx-hook="VegaLite"
      phx-update="ignore"
      id={@id}
      data-id={@id}
    />
    """
  end

  def bar(data, title \\ "", x \\ "date", y \\ "total") do
    Vl.new(title: title, width: :container, height: :container, padding: 5)
    |> Vl.config(
      title: [anchor: "start", color: "#ffffff"],
      view: [stroke: :transparent],
      background: nil
    )
    |> Vl.data_from_values(data, only: [x, y])
    |> Vl.mark(:bar, tooltip: true, color: "#a870ff", corner_radius_end: 3)
    |> Vl.encode_field(:x, x, type: :ordinal, title: String.capitalize(x), axis: [label_color: "#ffffff"])
    |> Vl.encode_field(:y, y, type: :quantitative, title: String.capitalize(y), axis: nil)
    |> Vl.to_spec()
  end
end
