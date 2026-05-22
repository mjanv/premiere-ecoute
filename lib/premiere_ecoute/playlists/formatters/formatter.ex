defprotocol PremiereEcoute.Playlists.Formatters.Formatter do
  @moduledoc """
  Protocol for formatting a library playlist into a target output format.

  Implement this protocol with a struct carrying any format-specific options.
  """

  @spec format(t(), PremiereEcoute.Discography.LibraryPlaylist.t()) :: {:ok, binary()} | {:error, term()}
  def format(formatter, playlist)
end
