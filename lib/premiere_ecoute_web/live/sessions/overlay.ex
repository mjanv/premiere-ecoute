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

  # Vertical label drawn in an SVG: the text is stretched to `label_length/1` units
  # and the SVG scales to the strip, so the label fills it with any font.
  defp label_text(user, score), do: user |> score_label(score) |> String.upcase()

  defp label_length(user, score), do: String.length(score_label(user, score)) * 52

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
