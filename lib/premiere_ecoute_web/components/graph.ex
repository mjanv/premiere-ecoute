defmodule PremiereEcouteWeb.Components.Live.Graph do
  @moduledoc false

  use PremiereEcouteWeb, :live_component

  require VegaLite, as: Vl

  @impl true
  def update(assigns, socket) do
    %{id: id, title: title, data: data, x: x, y: y} = assigns
    sort = Map.get(assigns, :sort, "ascending")
    stack_by = Map.get(assigns, :stack_by, nil)

    spec =
      if stack_by do
        stacked_bar(data, title, x, y, stack_by, sort)
      else
        bar(data, title, x, y, sort)
      end

    socket
    |> assign(id: id)
    |> push_event("vega_lite:#{id}:init", %{"spec" => spec})
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

  def bar(data, title \\ "", x \\ "date", y \\ "total", sort \\ "ascending") do
    x_sort = if sort == "none", do: nil, else: sort

    Vl.new(title: title, width: :container, height: :container, padding: 5)
    |> Vl.config(
      title: [anchor: "start", color: "#ffffff"],
      view: [stroke: :transparent],
      background: nil
    )
    |> Vl.data_from_values(data, only: [x, y])
    |> Vl.mark(:bar, tooltip: true, color: "#a870ff", corner_radius_end: 3)
    |> Vl.encode_field(:x, x, type: :ordinal, sort: x_sort, title: String.capitalize(x), axis: [label_color: "#ffffff"])
    |> Vl.encode_field(:y, y, type: :quantitative, title: String.capitalize(y), axis: nil)
    |> Vl.to_spec()
  end

  def stacked_bar(data, title \\ "", x \\ "date", y \\ "count", stack_by \\ "type", sort \\ "ascending") do
    x_sort = if sort == "none", do: nil, else: sort

    Vl.new(title: title, width: :container, height: :container, padding: 5)
    |> Vl.config(
      title: [anchor: "start", color: "#ffffff"],
      view: [stroke: :transparent],
      background: nil
    )
    |> Vl.data_from_values(data, only: [x, y, stack_by])
    |> Vl.mark(:bar, tooltip: true, corner_radius_end: 3)
    |> Vl.encode_field(:x, x, type: :ordinal, sort: x_sort, title: String.capitalize(x), axis: [label_color: "#ffffff"])
    |> Vl.encode_field(:y, y, type: :quantitative, title: String.capitalize(y), axis: nil, stack: true)
    |> Vl.encode_field(:color, stack_by,
      type: :nominal,
      scale: [
        domain: ["Paid", "Gift", "Prime"],
        range: ["#ec4899", "#a855f7", "#f97316"]
      ],
      legend: [orient: "bottom", title: nil, label_color: "#ffffff"]
    )
    |> Vl.to_spec()
  end
end
