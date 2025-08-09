defmodule PremiereEcoute.Accounts.Services.AccountRegistration do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.User

  @type twitch_data() :: %{
          required(:user_id) => String.t(),
          required(:email) => String.t(),
          required(:username) => String.t(),
          required(:display_name) => String.t(),
          required(:broadcaster_type) => String.t(),
          required(:access_token) => String.t(),
          required(:refresh_token) => String.t(),
          required(:expires_in) => integer()
        }

  @type spotify_data() :: %{
          required(:user_id) => String.t(),
          required(:email) => String.t(),
          required(:display_name) => String.t(),
          required(:country) => String.t(),
          required(:product) => String.t(),
          required(:access_token) => String.t(),
          required(:refresh_token) => String.t(),
          required(:expires_in) => integer()
        }

  @admins Application.compile_env(:premiere_ecoute, [PremiereEcoute.Accounts, :admins])
  @bots Application.compile_env(:premiere_ecoute, [PremiereEcoute.Accounts, :bots])

  @spec register_twitch_user(twitch_data(), String.t() | nil) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_twitch_user(%{email: email, username: username} = payload, password \\ nil) do
    with email <- if(email == "", do: "#{username}@twitch.tv", else: email),
         nil <- User.get_user_by_email(email),
         attrs <- %{
           email: email,
           username: username,
           role: role(payload),
           confirmed_at: DateTime.utc_now(),
           password: password || random(32)
         },
         {:ok, user} <- User.create(attrs),
         {:ok, user} <- User.create_token(user, :twitch, payload) do
      {:ok, user}
    else
      %User{} = user ->
        case User.refresh_token(user, :twitch, payload) do
          {:error, _} -> User.create_token(user, :twitch, payload)
          other -> other
        end

      {:error, reason} ->
        Logger.error("Failed to create user from Twitch authentification: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec register_spotify_user(spotify_data(), String.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_spotify_user(payload, id) do
    with %User{} = user <- Accounts.get_user!(id),
         {:ok, user} <- User.create_token(user, :spotify, payload) do
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
      {_, username} when username in @admins -> :admin
      {_, username} when username in @bots -> :bot
      {"affiliate", _} -> :streamer
      {"partner", _} -> :streamer
      _ -> :viewer
    end
  end

  defp random(n), do: Base.encode64(:crypto.strong_rand_bytes(n))
end
