defmodule PremiereEcouteWeb.Sessions.Overlay do
  @moduledoc """
  Session overlay components for streaming.

  Provides Phoenix components for displaying listening session scores in OBS overlays, including score value extraction and label formatting for viewer and streamer scores.
  """

  use Phoenix.Component

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
  defp score_label(%{username: username}, :streamer), do: username
  defp score_label(_user, :streamer), do: "Streamer"

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
  def bar_remaining_color(_state, _c1, _c2), do: "rgba(255,255,255,0.3)"
end
