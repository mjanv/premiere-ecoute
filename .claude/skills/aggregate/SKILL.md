---
name: aggregate
description: How to define and use Aggregates (Ecto schemas with generated CRUD) in this codebase.
---

# Aggregate

Aggregates are Ecto schemas with auto-generated CRUD via `use PremiereEcouteCore.Aggregate`.

## Define an aggregate

```elixir
defmodule PremiereEcoute.MyContext.MyThing do
  use Ecto.Schema
  use PremiereEcouteCore.Aggregate,
    root: [:association_name],   # preloaded on every read
    identity: [:user_id],        # fields used by create_if_not_exists/exists?
    json: [:id, :name, :status]  # fields exposed in JSON

  schema "my_things" do
    field :name, :string
    belongs_to :user, PremiereEcoute.Users.User
    timestamps()
  end

  def changeset(thing, attrs), do: thing |> cast(attrs, [:name]) |> validate_required([:name])
end
```

- `:root` — list of association atoms; all reads call `Repo.preload(result, root, force: true)` automatically
- `:identity` — used by `create_if_not_exists/1` and `exists?/1` to check uniqueness
- `:json` — drives the auto-generated `Jason.Encoder` impl

## Generated functions

```elixir
MyThing.create(%{name: "x", user_id: 1})           # insert, returns {:ok, thing} | {:error, cs}
MyThing.create_if_not_exists(%{user_id: 1})         # no-op if identity fields match existing row
MyThing.get(id)                                     # by primary key, returns thing | nil
MyThing.get_by(user_id: 1)                          # by arbitrary clauses
MyThing.all(user_id: 1)                             # list by clauses
MyThing.exists?(%MyThing{user_id: 1})               # boolean check on identity fields
MyThing.update(thing, %{name: "y"})                 # update, returns {:ok, thing} | {:error, cs}
MyThing.upsert(thing, %{name: "y"})                 # same as update, alias
MyThing.delete(thing)                               # delete
MyThing.page(clauses, page, size)                   # paginated list
MyThing.count(query, :id)                           # aggregate: count
MyThing.form(thing, attrs)                          # alias for changeset/2
```

All read ops auto-preload `:root` associations. Returns are consistent: structs, not raw queries.

## Override any generated function

Just define the function in the module body — the macro marks all generated functions as `defoverridable`.
