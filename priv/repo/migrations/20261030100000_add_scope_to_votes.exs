defmodule PremiereEcoute.Repo.Migrations.AddScopeToVotes do
  use Ecto.Migration

  def change do
    alter table(:votes) do
      add :scope, :string, null: false, default: "track"
      modify :track_id, :integer, null: true, from: {:integer, null: false}
    end

    create constraint(:votes, :vote_scope_track,
             check:
               "(scope = 'track' AND track_id IS NOT NULL) OR (scope = 'album' AND track_id IS NULL)"
           )

    create unique_index(:votes, [:viewer_id, :session_id],
             where: "scope = 'album'",
             name: :album_vote_index
           )
  end
end
