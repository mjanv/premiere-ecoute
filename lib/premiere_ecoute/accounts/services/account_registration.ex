defmodule PremiereEcoute.Accounts.Services.AccountRegistration do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.User

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

  @spec register_twitch_user(twitch_data()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_twitch_user(payload) do
    with email <- "#{payload.username}@twitch.tv",
         nil <- Accounts.get_user_by_email(email),
         attrs <- %{email: email, role: role(payload), password: random(32)},
         {:ok, user} <- Accounts.register_user(attrs),
         {:ok, user} <- User.update_twitch_auth(user, payload) do
      {:ok, user}
    else
      %User{} = user ->
        Accounts.User.update_twitch_auth(user, payload)

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
