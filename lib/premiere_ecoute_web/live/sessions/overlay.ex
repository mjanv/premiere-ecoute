defmodule PremiereEcouteWeb.Sessions.Overlay do
  @moduledoc false

  use Phoenix.Component

  embed_templates "overlay/*"

  defp score_value(nil, _), do: "-"
  defp score_value(summary, :viewer), do: summary["viewer_score"] || summary.viewer_score
  defp score_value(summary, :streamer), do: summary["streamer_score"] || summary.streamer_score
  defp score_label(:viewer), do: "Chat"
  defp score_label(:streamer), do: "Streamer"
end
