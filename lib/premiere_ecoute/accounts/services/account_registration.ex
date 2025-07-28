defmodule PremiereEcoute.Accounts.Services.AccountRegistration do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.EventStore

  @type twitch_data() :: %{
          required(:user_id) => String.t(),
          required(:access_token) => String.t(),
          required(:refresh_token) => String.t(),
          required(:expires_in) => integer(),
          required(:username) => String.t(),
          required(:display_name) => String.t(),
          required(:broadcaster_type) => String.t()
        }

  @type spotify_data() :: %{
          required(:access_token) => String.t(),
          required(:refresh_token) => String.t(),
          required(:expires_in) => integer()
        }

  @spec register_twitch_user(twitch_data(), String.t() | nil) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_twitch_user(%{username: username} = payload, password \\ nil) do
    with email <- "#{username}@twitch.tv",
         nil <- User.get_user_by_email(email),
         attrs <- %{email: email, role: role(payload), password: password || random(32)},
         {:ok, user} <- User.create(attrs),
         {:ok, user} <- User.update_twitch_auth(user, payload) do
      {:ok, user}
      |> EventStore.ok("user", fn user -> %AccountCreated{id: to_string(user.id), twitch_user_id: user.twitch_user_id} end)
    else
      %User{} = user ->
        User.update_twitch_auth(user, payload)

      {:error, reason} ->
        Logger.error("Failed to create user from Twitch authentification: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec register_spotify_user(spotify_data(), String.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_spotify_user(payload, id) do
    with %User{} = user <- Accounts.get_user!(id),
         {:ok, user} <- User.update_spotify_tokens(user, payload) do
      {:ok, user}
    else
      nil ->
        {:error, nil}

      {:error, reason} ->
        Logger.error("Failed to update user from Spotify authentification: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec role(map()) :: :admin | :bot | :streamer | :viewer
  def role(auth_data) do
    case {auth_data.broadcaster_type, auth_data.username} do
      {_, "lanfeust313"} -> :admin
      {_, "premiereecoutebot"} -> :bot
      {"affiliate", _} -> :streamer
      {"partner", _} -> :streamer
      _ -> :viewer
    end
  end

  defp random(n), do: Base.encode64(:crypto.strong_rand_bytes(n))
end
