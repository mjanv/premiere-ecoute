defmodule PremiereEcoute.Accounts.User do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias PremiereEcoute.Repo

  @type t :: %__MODULE__{
          id: integer() | nil,
          email: String.t() | nil,
          password: String.t() | nil,
          hashed_password: String.t() | nil,
          confirmed_at: DateTime.t() | nil,
          authenticated_at: DateTime.t() | nil,
          role: :streamer | :admin,
          spotify_access_token: String.t() | nil,
          spotify_refresh_token: String.t() | nil,
          spotify_expires_at: DateTime.t() | nil,
          twitch_user_id: String.t() | nil,
          twitch_access_token: String.t() | nil,
          twitch_refresh_token: String.t() | nil,
          twitch_expires_at: DateTime.t() | nil,
          twitch_username: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :role, Ecto.Enum, values: [:streamer, :admin], default: :streamer

    field :spotify_access_token, :string, redact: true
    field :spotify_refresh_token, :string, redact: true
    field :spotify_expires_at, :utc_datetime

    field :twitch_user_id, :string
    field :twitch_access_token, :string, redact: true
    field :twitch_refresh_token, :string, redact: true
    field :twitch_expires_at, :utc_datetime
    field :twitch_username, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [
      :email,
      :role,
      :twitch_user_id,
      :twitch_access_token,
      :twitch_refresh_token,
      :twitch_expires_at,
      :twitch_username
    ])
    |> validate_email(opts)
    |> validate_inclusion(:role, [:streamer, :admin])
  end

  def email_changeset(user, attrs \\ %{}, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, PremiereEcoute.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs \\ %{}, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    change(user, confirmed_at: DateTime.utc_now(:second))
  end

  @doc """
  A user changeset for updating Spotify tokens.
  """
  def spotify_changeset(user, attrs) do
    user
    |> cast(attrs, [:spotify_access_token, :spotify_refresh_token, :spotify_expires_at])
    |> validate_spotify_tokens()
  end

  @doc """
  A user changeset for disconnecting Spotify (allows nil values).
  """
  def spotify_disconnect_changeset(user, attrs) do
    user
    |> cast(attrs, [:spotify_access_token, :spotify_refresh_token, :spotify_expires_at])
  end

  defp validate_spotify_tokens(changeset) do
    case get_change(changeset, :spotify_access_token) do
      nil -> changeset
      _ -> validate_required(changeset, [:spotify_access_token])
    end
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%PremiereEcoute.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  def get!(id), do: Repo.get!(__MODULE__, id)

  def get_by(opts), do: Repo.get_by(__MODULE__, opts)

  def register_user(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def update(changeset) do
    changeset
    |> Repo.update()
  end

  def update_spotify_tokens(user, %{
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: expires_in
      }) do
    user
    |> spotify_changeset(%{
      spotify_access_token: access_token,
      spotify_refresh_token: refresh_token,
      spotify_expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
    })
    |> Repo.update()
  end

  def disconnect_spotify(user) do
    user
    |> spotify_disconnect_changeset(%{
      spotify_access_token: nil,
      spotify_refresh_token: nil,
      spotify_expires_at: nil
    })
    |> Repo.update()
  end

  @doc """
  A user changeset for updating Twitch tokens and user data.
  """
  def twitch_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :twitch_user_id,
      :twitch_access_token,
      :twitch_refresh_token,
      :twitch_expires_at,
      :twitch_username
    ])
    |> validate_twitch_tokens()
  end

  @doc """
  A user changeset for updating only Twitch tokens (during refresh).
  """
  def twitch_token_refresh_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :twitch_access_token,
      :twitch_refresh_token,
      :twitch_expires_at
    ])
    |> validate_required([:twitch_access_token])
  end

  defp validate_twitch_tokens(changeset) do
    case get_change(changeset, :twitch_access_token) do
      nil -> changeset
      _ -> validate_required(changeset, [:twitch_user_id, :twitch_access_token, :twitch_username])
    end
  end

  @doc """
  Updates user with Twitch auth data from login (includes user_id and username).
  """
  def update_twitch_auth(user, %{
        user_id: user_id,
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: expires_in,
        username: username
      }) do
    user
    |> twitch_changeset(%{
      twitch_user_id: user_id,
      twitch_access_token: access_token,
      twitch_refresh_token: refresh_token,
      twitch_expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second),
      twitch_username: username
    })
    |> Repo.update()
  end

  @doc """
  Updates user with refreshed Twitch tokens (no user_id/username).
  """
  def update_twitch_tokens(user, %{
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: expires_in
      }) do
    user
    |> twitch_token_refresh_changeset(%{
      twitch_access_token: access_token,
      twitch_refresh_token: refresh_token,
      twitch_expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
    })
    |> Repo.update()
  end

  # Handle case where expires_in is not provided
  def update_twitch_tokens(user, %{
        access_token: access_token,
        refresh_token: refresh_token
      }) do
    user
    |> twitch_token_refresh_changeset(%{
      twitch_access_token: access_token,
      twitch_refresh_token: refresh_token
    })
    |> Repo.update()
  end

  @doc """
  Disconnects Twitch by clearing all Twitch tokens and data.
  """
  def disconnect_twitch(user) do
    user
    |> cast(
      %{
        twitch_user_id: nil,
        twitch_access_token: nil,
        twitch_refresh_token: nil,
        twitch_expires_at: nil,
        twitch_username: nil
      },
      [
        :twitch_user_id,
        :twitch_access_token,
        :twitch_refresh_token,
        :twitch_expires_at,
        :twitch_username
      ]
    )
    |> Repo.update()
  end

  def all, do: Repo.all(__MODULE__)
end
