defmodule PremiereEcoute.Repo.Migrations.AddProviderIdsToRadioTracks do
  use Ecto.Migration

  def up do
    alter table(:radio_tracks) do
      add :provider_ids, :map, default: %{}
    end

    execute "UPDATE radio_tracks SET provider_ids = jsonb_build_object('spotify', provider_id)"

    alter table(:radio_tracks) do
      remove :provider_id
    end
  end

  def down do
    alter table(:radio_tracks) do
      add :provider_id, :string
    end

    execute "UPDATE radio_tracks SET provider_id = provider_ids->>'spotify'"

    alter table(:radio_tracks) do
      remove :provider_ids
    end
  end
end
