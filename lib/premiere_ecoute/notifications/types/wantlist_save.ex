defmodule PremiereEcoute.Notifications.Types.WantlistSave do
  @moduledoc """
  Notification type for a track saved to the wantlist.

  Dispatched from the radio page heart button and the Twitch !save command.
  """

  @behaviour PremiereEcoute.Notifications.NotificationType

  @enforce_keys [:track_name, :artist_name]
  defstruct [:track_name, :artist_name]

  @type t :: %__MODULE__{track_name: String.t(), artist_name: String.t()}

  @impl true
  def type, do: "wantlist_save"

  @impl true
  def channels, do: [:pubsub]

  @impl true
  def render(%__MODULE__{track_name: track, artist_name: artist}),
    do: render(%{"track_name" => track, "artist_name" => artist})

  def render(%{"track_name" => track, "artist_name" => artist}) do
    %{
      title: track,
      body: artist,
      icon: "heart",
      path: "/wantlist"
    }
  end
end
