defmodule PremiereEcoute.Analytics.Tracking do
  @moduledoc """
  PostHog event tracking.
  """

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.Album

  @spec album_viewed(User.t(), Album.t()) :: :ok
  def album_viewed(%User{id: user_id}, %Album{id: album_id, name: album_name}) do
    capture("album_viewed", user_id, album_id: album_id, album_name: album_name)
  end

  defp capture(event, user_id, properties) do
    PostHog.capture(event, [distinct_id: user_id] ++ properties, [])
    :ok
  end
end
