defmodule PremiereEcoute.Sessions.TitleTemplate do
  @moduledoc """
  Renders YouTube title templates with session-derived variable substitution.

  Supported variables: {show_name}, {title}, {artist}, {streamer_score}, {viewer_score}
  """

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report

  @variables ~w(show_name title artist streamer_score viewer_score)

  @doc "Returns the list of supported variable names."
  @spec variables() :: [String.t()]
  def variables, do: @variables

  @doc "Renders a title template given a session and its report."
  @spec render(String.t(), String.t(), ListeningSession.t(), Report.t() | nil) :: String.t()
  def render(template, show_name, session, report) do
    streamer_score = report && report.session_summary["streamer_score"]
    viewer_score = report && report.session_summary["viewer_score"]

    template
    |> String.replace("{show_name}", show_name || "")
    |> String.replace("{title}", ListeningSession.title(session) || "")
    |> String.replace("{artist}", ListeningSession.artist(session) || "")
    |> String.replace("{streamer_score}", format_score(streamer_score))
    |> String.replace("{viewer_score}", format_score(viewer_score))
  end

  defp format_score(nil), do: "?"
  defp format_score(score) when is_float(score), do: :erlang.float_to_binary(score, decimals: 2)
  defp format_score(score), do: to_string(score)
end
