defmodule Mix.Tasks.Billboard do
  @moduledoc """
  Mix task to process Spotify public playlist URLs and generate a billboard of tracks with counters.

  Usage:
    mix albums
  """

  use Mix.Task
  use Boundary, classify_to: PremiereEcouteMix

  alias PremiereEcoute.Discography.Billboard

  @shortdoc "Generate a billboard of tracks from Spotify playlists"

  def run(_args) do
    Application.ensure_all_started(:req)

    Application.put_env(:premiere_ecoute, :spotify_client_id, System.get_env("SPOTIFY_CLIENT_ID"))
    Application.put_env(:premiere_ecoute, :spotify_client_secret, System.get_env("SPOTIFY_CLIENT_SECRET"))

    with {:ok, content} <- File.read("priv/playlists.txt"),
         playlists <- String.split(content, "\n"),
         {:ok, tracks} <- Billboard.generate_billboard(playlists) do
      display_billboard(Enum.take(tracks, 50))
    else
      {:error, reason} -> Mix.shell().error("Error generating billboard: #{reason}")
    end
  end

  defp display_billboard(tracks) do
    Mix.shell().info("")
    Mix.shell().info("")
    Mix.shell().info("")

    ascii_header = Billboard.generate_ascii_header()
    Mix.shell().info(IO.ANSI.magenta() <> Enum.at(ascii_header, 0) <> IO.ANSI.reset())
    Mix.shell().info(IO.ANSI.cyan() <> Enum.at(ascii_header, 1) <> IO.ANSI.reset())
    Mix.shell().info(IO.ANSI.green() <> Enum.at(ascii_header, 2) <> IO.ANSI.reset())
    Mix.shell().info(IO.ANSI.yellow() <> Enum.at(ascii_header, 3) <> IO.ANSI.reset())
    Mix.shell().info(IO.ANSI.red() <> Enum.at(ascii_header, 4) <> IO.ANSI.reset())
    Mix.shell().info(IO.ANSI.blue() <> Enum.at(ascii_header, 5) <> IO.ANSI.reset())
    Mix.shell().info("")

    tracks
    |> Enum.with_index(1)
    |> Enum.each(fn {%{track: track, count: count}, rank} ->
      {color, icon} = rank_style(rank)
      rank = color <> String.pad_leading("#{icon} #{rank}", 6) <> IO.ANSI.reset()
      count = count_style(count) <> "[#{count}x]" <> IO.ANSI.reset()
      artist = IO.ANSI.bright() <> track.artist <> IO.ANSI.reset()
      name = IO.ANSI.white() <> track.name <> IO.ANSI.reset()

      Mix.shell().info("#{rank} #{count} #{artist} - #{name}")
    end)

    Mix.shell().info("")
    Mix.shell().info("")
    Mix.shell().info("")
  end

  defp rank_style(1), do: {IO.ANSI.yellow(), "🥇"}
  defp rank_style(2), do: {IO.ANSI.white(), "🥈"}
  defp rank_style(3), do: {IO.ANSI.color(3, 1, 0), "🥉"}
  defp rank_style(_), do: {IO.ANSI.cyan(), "•"}

  defp count_style(count) when count >= 10, do: IO.ANSI.red()
  defp count_style(count) when count >= 5, do: IO.ANSI.yellow()
  defp count_style(count) when count >= 2, do: IO.ANSI.green()
  defp count_style(_), do: IO.ANSI.white()
end
