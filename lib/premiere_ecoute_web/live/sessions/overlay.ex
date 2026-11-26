defmodule PremiereEcouteWeb.Sessions.Overlay do
  @moduledoc """
  Session overlay components for streaming.

  Provides Phoenix components for displaying listening session scores in OBS overlays, including score value extraction and label formatting for viewer and streamer scores.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcouteWeb.Sessions.Components.SessionComponents

  embed_templates "overlay/*"

  defp score_value(nil, _), do: "-"

  defp score_value(summary, :viewer) do
    case summary["viewer_score"] || Map.get(summary, :viewer_score) do
      nil -> "-"
      +0.0 -> "-"
      10.0 -> "10"
      score -> Float.to_string(score)
    end
  end

  defp score_value(summary, :streamer) do
    case summary["streamer_score"] || Map.get(summary, :streamer_score) do
      nil -> "-"
      +0.0 -> "-"
      score -> Integer.to_string(trunc(score))
    end
  end

  defp score_nil?(nil, _), do: true
  defp score_nil?(summary, :viewer), do: is_nil(summary["viewer_score"] || Map.get(summary, :viewer_score))
  defp score_nil?(summary, :streamer), do: is_nil(summary["streamer_score"] || Map.get(summary, :streamer_score))

  # Identifies what the score box shows, so the DitherSwap hook only animates real
  # swaps: a change of vote state or of kind of content, never a new score value.
  defp swap_key(%AsyncResult{ok?: true, result: summary}, state, score),
    do: "#{state}:#{swap_content(summary, state, score)}"

  defp swap_key(_summary, state, _score), do: "#{state}:loading"

  defp swap_content(_summary, :closed, _score), do: "lock"

  defp swap_content(summary, :open, score) do
    if score_nil?(summary, score), do: "unlock", else: score_kind(summary, score)
  end

  defp swap_content(summary, _state, score), do: score_kind(summary, score)

  defp score_kind(summary, score), do: if(score_value(summary, score) == "-", do: "empty", else: "score")

  # Scores at or above this switch the overlay to the "great score" liquid paint.
  @great_score 9.5
  # In great mode every overlay colour is painted white; the LiquidField layer then
  # multiplies the whole widget by a flowing gradient, so white turns into the gradient
  # and black stays black.
  @great_paint "#ffffff"
  # Remaining part of the progress bar in great mode: a mid grey, so it reads as a
  # darker tone of the gradient next to the played cells.
  @great_remaining "#5c5c5c"

  @doc """
  Whether the shown score is a great one (at least #{@great_score}).
  """
  @spec great?(AsyncResult.t(), atom()) :: boolean()
  def great?(%AsyncResult{ok?: true, result: summary}, score) when is_map(summary) and score in [:viewer, :streamer],
    do: great_score?(summary, score)

  def great?(%AsyncResult{ok?: true, result: summary}, :both) when is_map(summary),
    do: great_score?(summary, :viewer) or great_score?(summary, :streamer)

  def great?(_summary, _score), do: false

  @doc """
  Resolves the colours the overlay paints with and yields them to its block as
  `%{great: boolean, primary: colour, secondary: colour, text: colour}`: the user's
  colours, or white in great mode.
  """
  attr :primary, :string, required: true
  attr :secondary, :string, required: true
  attr :summary, AsyncResult, required: true
  attr :score, :atom, required: true
  attr :widget_state, :atom, required: true
  slot :inner_block, required: true

  def paint(assigns) do
    great = great?(assigns.summary, assigns.score)
    primary = if great, do: @great_paint, else: assigns.primary
    secondary = if great, do: @great_paint, else: assigns.secondary

    assigns =
      assign(assigns, :paint, %{
        great: great,
        primary: primary,
        secondary: secondary,
        text: widget_text_color(assigns.widget_state, primary, secondary)
      })

    ~H"{render_slot(@inner_block, @paint)}"
  end

  # Background of the black areas, hard-coded for now:
  # - :constellation, chat votes drawn as stars, over a paper texture without specks;
  # - :texture, the paper texture with its specks (which read as stars), and no stars.
  @background :constellation

  @doc """
  Background of the overlay's black areas: `:constellation` or `:texture`.
  """
  @spec background() :: :constellation | :texture
  def background, do: @background

  @doc """
  A full-widget canvas layer driven by a JS hook and blended over the widget. With
  `behind`, the layer sits under the widget content instead (over the root background,
  under borders, text and progress bar).
  """
  attr :id, :string, required: true
  attr :hook, :string, required: true
  attr :blend, :string, required: true
  attr :behind, :boolean, default: false

  def layer(assigns) do
    ~H"""
    <canvas
      id={@id}
      phx-hook={@hook}
      phx-update="ignore"
      aria-hidden="true"
      style={"position: absolute; inset: 0; width: 100%; height: 100%; mix-blend-mode: #{@blend}; pointer-events: none; z-index: #{if @behind, do: -1, else: 2};"}
    ></canvas>
    """
  end

  defp remaining_color(true, _state, _c1, _c2), do: @great_remaining
  defp remaining_color(false, state, c1, c2), do: bar_remaining_color(state, c1, c2)

  defp great_score?(summary, score) do
    case summary["#{score}_score"] || Map.get(summary, :"#{score}_score") do
      value when is_number(value) -> value >= @great_score
      _ -> false
    end
  end

  defp score_label(_user, :viewer), do: "Chat"
  defp score_label(_user, :streamer), do: "Streamer"
  defp score_label(_user, :votes), do: "Votes"
  defp score_label(_user, :player), do: "Playing"

  # Big score value drawn in an SVG that scales to fill the score box.
  attr :id, :string, required: true
  attr :value, :string, required: true
  attr :color, :string, required: true

  defp big_value(assigns) do
    assigns = assign(assigns, :length, assigns.value |> String.graphemes() |> Enum.map(&glyph_width/1) |> Enum.sum())

    ~H"""
    <svg
      id={@id}
      phx-hook="FitSvgText"
      data-fill="0.62"
      viewBox={"0 0 #{@length + 40} 112"}
      preserveAspectRatio="xMidYMid meet"
      style="width: 100%; height: 100%; display: block;"
    >
      <g>
        <text
          x={(@length + 40) / 2}
          y="92"
          text-anchor="middle"
          textLength={@length}
          lengthAdjust="spacingAndGlyphs"
          font-size="100"
          font-family="Overlay"
          font-weight="700"
          fill={@color}
          stroke={@color}
          stroke-width="5"
          stroke-linejoin="round"
        >
          {@value}
        </text>
      </g>
    </svg>
    """
  end

  defp glyph_width("."), do: 30
  defp glyph_width("-"), do: 42
  defp glyph_width(_), do: 58

  # Vertical label drawn in an SVG: the text is stretched to `label_length/3` units
  # and the SVG scales to the strip, so the label fills it with any font.
  defp label_text(user, score, summary), do: user |> strip_label(score, summary) |> String.upcase()

  defp label_length(user, score, summary), do: String.length(strip_label(user, score, summary)) * 52

  # Easter egg: the label cheers when the shown score is exactly 6.7.
  defp strip_label(user, score, summary) do
    if six_seven?(summary, score), do: "Six seven!", else: score_label(user, score)
  end

  defp six_seven?(%AsyncResult{ok?: true, result: summary}, score) when score in [:viewer, :streamer],
    do: score_value(summary, score) == "6.7"

  defp six_seven?(_summary, _score), do: false

  # Height shared by the track counter and the progress bar, so they line up.
  defp bar_height, do: "18vh"

  defp track_counter(%AsyncResult{ok?: true, result: %{item: %{track_number: n, album: %{total_tracks: t}}}}),
    do: "#{n}/#{t}"

  defp track_counter(_progress), do: "-/-"

  @doc """
  Returns the widget background color for a vote state.
  """
  @spec widget_bg(atom(), String.t(), String.t()) :: String.t()
  def widget_bg(:idle, _c1, _c2), do: "#000000"
  def widget_bg(:closed, c1, _c2), do: c1
  def widget_bg(:open, _c1, _c2), do: "#000000"
  def widget_bg(:ended, _c1, _c2), do: "#000000"

  @doc """
  Returns the widget text color for a vote state.
  """
  @spec widget_text_color(atom(), String.t(), String.t()) :: String.t()
  def widget_text_color(:idle, c1, _c2), do: c1
  def widget_text_color(:closed, _c1, _c2), do: "#000000"
  def widget_text_color(:open, c1, _c2), do: c1
  def widget_text_color(:ended, c1, _c2), do: c1

  @doc """
  Returns the color of the played part of the progress bar.
  """
  @spec bar_played_color(atom(), String.t(), String.t()) :: String.t()
  def bar_played_color(_state, _c1, c2), do: c2

  @doc """
  Returns the color of the remaining part of the progress bar.
  """
  @spec bar_remaining_color(atom(), String.t(), String.t()) :: String.t()
  def bar_remaining_color(_state, _c1, _c2), do: "#d4d4cc"
end
