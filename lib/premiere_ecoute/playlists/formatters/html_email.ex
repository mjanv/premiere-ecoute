defmodule PremiereEcoute.Playlists.Formatters.HtmlEmail do
  @moduledoc """
  Formats a library playlist as an HTML email body.

  Renders title, cover image (when present), and track count.
  """

  defstruct tracks: [], track_count: nil, cover_url: nil

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.Formatters.Formatter

  defimpl Formatter do
    def format(%{tracks: tracks, track_count: track_count, cover_url: cover_url}, %LibraryPlaylist{} = playlist) do
      playlist = %{playlist | track_count: track_count || playlist.track_count, cover_url: cover_url || playlist.cover_url}

      html = """
      <!DOCTYPE html>
      <html>
        <body style="font-family: sans-serif; background: #0f0f0f; color: #ffffff; margin: 0; padding: 0;">
          <div style="max-width: 600px; margin: 0 auto; padding: 32px 24px;">

            #{header(playlist)}

            #{track_list(tracks)}

            <p style="font-size: 12px; color: #666; text-align: center; margin-top: 32px;">
              You are receiving this email because you subscribed to updates for this playlist.
            </p>
          </div>
        </body>
      </html>
      """

      {:ok, html}
    end

    # Prevents XSS from Spotify-sourced data (track names, artist names, playlist title, URLs).
    defp escape(value), do: value |> to_string() |> Plug.HTML.html_escape()

    defp header(playlist) do
      cover = cover_img(playlist.cover_url)
      count = playlist.track_count || 0

      """
      <div style="display: flex; align-items: center; gap: 16px; margin-bottom: 32px;">
        #{cover}
        <div>
          <h1 style="margin: 0 0 4px; font-size: 22px; color: #ffffff;">#{escape(playlist.title)}</h1>
          <p style="margin: 0; font-size: 14px; color: #aaaaaa;">#{count} tracks</p>
        </div>
      </div>
      <hr style="border: none; border-top: 1px solid #333; margin-bottom: 24px;" />
      """
    end

    defp cover_img(nil), do: ""

    defp cover_img(url) do
      ~s(<img src="#{escape(url)}" alt="cover" style="width: 80px; height: 80px; object-fit: cover; border-radius: 8px;" />)
    end

    defp track_list([]), do: ""

    defp track_list(tracks) do
      rows = Enum.with_index(tracks, 1) |> Enum.map_join("\n", fn {track, i} -> track_row(track, i) end)

      """
      <table style="width: 100%; border-collapse: collapse;">
        #{rows}
      </table>
      """
    end

    defp track_row(track, index) do
      spotify_url = "https://open.spotify.com/track/#{escape(track.track_id)}"
      duration = format_duration(track.duration_ms)

      """
      <tr style="border-bottom: 1px solid #222;">
        <td style="padding: 12px 8px; color: #555; font-size: 13px; width: 32px; text-align: center;">#{index}</td>
        <td style="padding: 12px 8px;">
          <a href="#{spotify_url}" style="text-decoration: none;">
            <div style="font-size: 14px; font-weight: 600; color: #ffffff;">#{escape(track.name)}</div>
            <div style="font-size: 13px; color: #aaaaaa; margin-top: 2px;">#{escape(track.artist)}</div>
          </a>
        </td>
        <td style="padding: 12px 8px; color: #555; font-size: 13px; text-align: right; white-space: nowrap;">#{duration}</td>
      </tr>
      """
    end

    defp format_duration(nil), do: ""

    defp format_duration(ms) do
      total_seconds = div(ms, 1000)
      minutes = div(total_seconds, 60)
      seconds = rem(total_seconds, 60)
      "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
    end
  end
end
