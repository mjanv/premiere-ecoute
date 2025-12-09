defmodule PremiereEcouteWeb.Components.Live.Graph do
  @moduledoc false

  use PremiereEcouteWeb, :live_component

  require VegaLite, as: Vl

  @impl true
  def update(assigns, socket) do
    %{id: id, title: title, data: data, x: x, y: y} = assigns
    sort = Map.get(assigns, :sort, "ascending")
    stack_by = Map.get(assigns, :stack_by, nil)
    format_type = Map.get(assigns, :format_type, nil)

    spec =
      if stack_by do
        stacked_bar(data, title, x, y, stack_by, sort, format_type)
      else
        bar(data, title, x, y, sort, format_type)
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

  @doc "Creates a bar chart VegaLite specification."
  @spec bar(list(map()), String.t(), String.t(), String.t(), String.t(), String.t() | nil) :: map()
  def bar(data, title \\ "", x \\ "date", y \\ "total", sort \\ "ascending", format_type \\ nil) do
    x_sort = if sort == "none", do: nil, else: sort

    tooltip_encoding =
      case format_type do
        "duration" ->
          [
            [field: x, type: :nominal],
            [field: y, type: :quantitative, format: ".0f", title: String.capitalize(y)]
          ]

        _ ->
          true
      end

    Vl.new(title: title, width: :container, height: :container, padding: 5)
    |> Vl.config(
      title: [anchor: "start", color: "#ffffff"],
      view: [stroke: :transparent],
      background: nil
    )
    |> Vl.data_from_values(data, only: [x, y])
    |> Vl.mark(:bar, tooltip: tooltip_encoding, color: "#a870ff", corner_radius_end: 3)
    |> Vl.encode_field(:x, x, type: :ordinal, sort: x_sort, title: String.capitalize(x), axis: [label_color: "#ffffff"])
    |> Vl.encode_field(:y, y, type: :quantitative, title: String.capitalize(y), axis: nil)
    |> Vl.to_spec()
  end

  @doc "Creates a stacked bar chart VegaLite specification."
  @spec stacked_bar(list(map()), String.t(), String.t(), String.t(), String.t(), String.t(), String.t() | nil) :: map()
  def stacked_bar(data, title \\ "", x \\ "date", y \\ "count", stack_by \\ "type", sort \\ "ascending", format_type \\ nil) do
    x_sort = if sort == "none", do: nil, else: sort

    tooltip_encoding =
      case format_type do
        "duration" ->
          [
            [field: x, type: :nominal],
            [field: stack_by, type: :nominal],
            [field: y, type: :quantitative, format: ".0f"]
          ]

        _ ->
          true
      end

    # Extract unique values for the stack_by field in the order they appear (preserves selection order)
    unique_values = data |> Enum.map(& &1[stack_by]) |> Enum.uniq()

    # Generate color palette - use predefined colors if they match known types, otherwise generate consistent colors
    color_encoding =
      if Enum.all?(["Paid", "Gift", "Prime"], &(&1 in unique_values)) do
        # Subscription types - use specific colors
        [
          type: :nominal,
          scale: [
            domain: ["Paid", "Gift", "Prime"],
            range: ["#ec4899", "#a855f7", "#f97316"]
          ],
          legend: [orient: "bottom", title: nil, label_color: "#ffffff"]
        ]
      else
        # Generic - explicitly define domain in order of appearance (preserves selection order)
        [
          type: :nominal,
          scale: [
            domain: unique_values,
            scheme: "category20"
          ],
          legend: [orient: "bottom", title: nil, label_color: "#ffffff"]
        ]
      end

    Vl.new(title: title, width: :container, height: :container, padding: 5)
    |> Vl.config(
      title: [anchor: "start", color: "#ffffff"],
      view: [stroke: :transparent],
      background: nil
    )
    |> Vl.data_from_values(data, only: [x, y, stack_by])
    |> Vl.mark(:bar, tooltip: tooltip_encoding, corner_radius_end: 3)
    |> Vl.encode_field(:x, x, type: :ordinal, sort: x_sort, title: String.capitalize(x), axis: [label_color: "#ffffff"])
    |> Vl.encode_field(:y, y, type: :quantitative, title: String.capitalize(y), axis: nil, stack: true)
    |> Vl.encode_field(:color, stack_by, color_encoding)
    |> Vl.to_spec()
  end
end
