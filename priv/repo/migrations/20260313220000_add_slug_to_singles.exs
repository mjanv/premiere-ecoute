defmodule PremiereEcoute.Repo.Migrations.AddSlugToSingles do
  use Ecto.Migration

  def up do
    alter table(:singles) do
      add :slug, :string
    end

    create index(:singles, [:slug])

    flush()

    execute("""
    UPDATE singles
    SET slug = regexp_replace(lower(name), '[^a-z0-9]+', '-', 'g')
    WHERE slug IS NULL AND name IS NOT NULL
    """)
  end

  def down do
    drop index(:singles, [:slug])

    alter table(:singles) do
      remove :slug
    end
  end
end
