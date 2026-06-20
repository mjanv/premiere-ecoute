defmodule PremiereEcoute.Analytics.Tracking do
  @moduledoc """
  PostHog event tracking. All functions accept a User struct as first argument.
  """

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.Album

  @spec album_viewed(User.t(), Album.t()) :: :ok
  def album_viewed(%User{id: user_id}, %Album{} = album) do
    capture("album_viewed", user_id,
      album_id: album.id,
      album_name: album.name
    )
  end

  defp capture(event, user_id, properties) do
    Posthog.capture(event, [distinct_id: user_id] ++ properties, [])
    :ok
  end
end
