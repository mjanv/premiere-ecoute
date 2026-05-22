defmodule PremiereEcoute.Playlists.Formatters.Csv do
  @moduledoc """
  Formats a library playlist as a CSV string.

  Columns: title, track_count, url, provider.
  """

  defstruct []

  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.Formatters.Formatter

  defimpl Formatter do
    def format(_formatter, %LibraryPlaylist{} = playlist) do
      header = "title,track_count,url,provider"
      row = ~s("#{playlist.title}",#{playlist.track_count},"#{playlist.url}",#{playlist.provider})

      {:ok, Enum.join([header, row], "\n")}
    end
  end
end
