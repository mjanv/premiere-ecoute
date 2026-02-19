defmodule PremiereEcouteWeb.Sessions.Overlay do
  @moduledoc """
  Session overlay components for streaming.

  Provides Phoenix components for displaying listening session scores in OBS overlays, including score value extraction and label formatting for viewer and streamer scores.
  """

  use Phoenix.Component

  embed_templates "overlay/*"

  defp score_value(nil, _), do: "-"

  defp score_value(summary, :viewer) do
    case summary["viewer_score"] || Map.get(summary, :viewer_score) do
      nil -> "?"
      score -> score
    end
  end

  defp score_value(summary, :streamer) do
    case summary["streamer_score"] || Map.get(summary, :streamer_score) do
      nil -> "?"
      score -> score
    end
  end

  defp score_label(:viewer), do: "Chat"
  defp score_label(:streamer), do: "Streamer"

  # AIDEV-NOTE: widget state color helpers — state is :idle | :closed | :open | :ended
  # Each state maps (background, text, progress bar played/remaining) to color1, color2, black, or white.
  # Public so they can be called from overlay_live.html.heex via the OverlayLive import.
  def widget_bg(:idle, _c1, _c2), do: "#000000"
  def widget_bg(:closed, _c1, _c2), do: "#000000"
  def widget_bg(:open, _c1, c2), do: c2
  def widget_bg(:ended, c1, _c2), do: c1

  def widget_text_color(:idle, c1, _c2), do: c1
  def widget_text_color(:closed, _c1, c2), do: c2
  def widget_text_color(:open, _c1, _c2), do: "#000000"
  def widget_text_color(:ended, _c1, _c2), do: "#000000"

  def bar_played_color(:idle, c1, _c2), do: c1
  def bar_played_color(:closed, _c1, _c2), do: "rgba(255,255,255,0.3)"
  def bar_played_color(:open, c1, _c2), do: c1
  def bar_played_color(:ended, _c1, c2), do: c2

  def bar_remaining_color(:idle, _c1, c2), do: c2
  def bar_remaining_color(:closed, c1, _c2), do: c1
  def bar_remaining_color(:open, _c1, c2), do: c2
  def bar_remaining_color(:ended, c1, _c2), do: c1
end
