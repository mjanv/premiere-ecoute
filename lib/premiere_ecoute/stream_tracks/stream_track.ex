defmodule PremiereEcoute.StreamTracks.StreamTrack do
  @moduledoc """
  Schema for tracks played during a Twitch stream.
  Completely decoupled from discography - only related to users.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias PremiereEcoute.Accounts.User

  schema "stream_tracks" do
    belongs_to :user, User

    field :provider_id, :string
    field :name, :string
    field :artist, :string
    field :album, :string
    field :duration_ms, :integer
    field :started_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(stream_track, attrs) do
    stream_track
    |> cast(attrs, [:user_id, :provider_id, :name, :artist, :album, :duration_ms, :started_at])
    |> validate_required([:user_id, :provider_id, :name, :artist, :started_at])
  end
end
