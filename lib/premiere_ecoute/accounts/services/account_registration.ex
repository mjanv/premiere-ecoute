defmodule PremiereEcoute.Accounts.Services.AccountRegistration do
  @moduledoc """
  Account registration service.

  Registers users via Twitch or Spotify OAuth, creates or updates OAuth tokens, assigns roles based on broadcaster type and configured lists (admins/bots/streamers), and generates random passwords for passwordless accounts.
  """

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
  @streamers Application.compile_env(:premiere_ecoute, [PremiereEcoute.Accounts, :streamers])

  @doc """
  Registers or updates a user via Twitch OAuth.

  Creates a new user account with OAuth tokens if the email is new, or refreshes/creates tokens for existing users. Automatically assigns role based on broadcaster type and configured lists. Generates random password if not provided.
  """
  @spec register_twitch_user(twitch_data(), String.t() | nil) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_twitch_user(%{email: email, username: username} = payload, password \\ nil) do
    with nil <- User.get_user_by_email(email),
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

  @doc """
  Associates Spotify OAuth credentials with an existing user account.

  Requires the user to already exist in the system. Creates Spotify OAuth tokens for the specified user, enabling Spotify API integration.
  """
  @spec register_spotify_user(spotify_data(), binary() | integer()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t() | nil}
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

  @doc """
  Determines user role based on Twitch authentication data.

  Checks username against configured admin, bot, and streamer lists first. Falls back
  to broadcaster type: partners become streamers, affiliates and others become viewers.
  """
  @spec role(map()) :: :admin | :bot | :streamer | :viewer
  def role(auth_data) do
    case {auth_data.broadcaster_type, auth_data.username} do
      {_, username} when username in @admins -> :admin
      {_, username} when username in @bots -> :bot
      {_, username} when username in @streamers -> :streamer
      {"partner", _} -> :streamer
      {"affiliate", _} -> :viewer
      _ -> :viewer
    end
  end

  defp random(n), do: Base.encode64(:crypto.strong_rand_bytes(n))
end
