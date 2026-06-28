defmodule PremiereEcoute.Notifications.Types.MissedSession do
  @moduledoc """
  Notification dispatched to a streamer's followers who cast no vote when their session stops.
  """

  @behaviour PremiereEcoute.Notifications.NotificationType

  @enforce_keys [:streamer_name, :session_title, :username, :share_token]
  defstruct [:streamer_name, :session_title, :username, :share_token]

  @type t :: %__MODULE__{
          streamer_name: String.t(),
          session_title: String.t(),
          username: String.t(),
          share_token: String.t()
        }

  @impl true
  def type, do: "missed_session"

  @impl true
  def channels, do: [:pubsub]

  @impl true
  def render(%__MODULE__{streamer_name: name, session_title: session_title, username: username, share_token: token}),
    do:
      render(%{
        "streamer_name" => name,
        "session_title" => session_title,
        "username" => username,
        "share_token" => token
      })

  def render(%{"streamer_name" => name, "session_title" => session_title, "username" => username, "share_token" => token}) do
    %{
      title: "You missed #{name}'s session",
      body: session_title,
      icon: "musical-note",
      path: "/sessions/#{username}/#{token}"
    }
  end
end
