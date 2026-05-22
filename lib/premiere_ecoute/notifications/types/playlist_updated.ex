defmodule PremiereEcoute.Notifications.Types.PlaylistUpdated do
  @moduledoc """
  Notification dispatched to subscribers when a playlist is updated.

  Clicking the notification opens the playlist's external provider URL in a new tab.
  """

  @behaviour PremiereEcoute.Notifications.NotificationType

  @enforce_keys [:playlist_title, :playlist_url]
  defstruct [:playlist_title, :playlist_url]

  @type t :: %__MODULE__{playlist_title: String.t(), playlist_url: String.t()}

  @impl true
  def type, do: "playlist_updated"

  @impl true
  def channels, do: [:pubsub]

  @impl true
  def render(%__MODULE__{playlist_title: title, playlist_url: url}),
    do: render(%{"playlist_title" => title, "playlist_url" => url})

  def render(%{"playlist_title" => title, "playlist_url" => url}) do
    %{
      title: title,
      body: "Playlist updated",
      icon: "music",
      path: url,
      target: "_blank"
    }
  end
end
