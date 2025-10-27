defmodule PremiereEcoute.Repo.Migrations.AddVisibilityToListeningSessions do
  use Ecto.Migration

  def change do
    # AIDEV-NOTE: visibility controls for session retrospectives (issue #17)
    # :private - only streamer, :protected - streamer + authenticated users, :public - everyone
    alter table(:listening_sessions) do
      add :visibility, :string, default: "protected", null: false
    end

    create constraint(:listening_sessions, :visibility_must_be_valid,
             check: "visibility IN ('private', 'protected', 'public')"
           )
  end
end
