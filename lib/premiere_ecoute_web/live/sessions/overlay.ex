defmodule PremiereEcouteWeb.Sessions.Overlay do
  @moduledoc false

  use Phoenix.Component

  embed_templates "overlay/*"

  # AIDEV-NOTE: Display "-" when score is nil or 0.0 (no note available)
  defp score_value(nil, _), do: "-"
  defp score_value(summary, :viewer) do
    score = summary["viewer_score"] || summary.viewer_score
    if score == 0.0, do: "-", else: score
  end
  defp score_value(summary, :streamer) do
    score = summary["streamer_score"] || summary.streamer_score
    if score == 0.0, do: "-", else: score
  end
  defp score_label(:viewer), do: "Chat"
  defp score_label(:streamer), do: "Streamer"
end
