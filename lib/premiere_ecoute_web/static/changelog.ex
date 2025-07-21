defmodule PremiereEcouteWeb.Static.Changelog.Entry do
  @moduledoc false

  @enforce_keys [:id, :title, :date, :body]
  defstruct [:id, :title, :date, :body]

  def build(filename, attrs, body) do
    [id] = filename |> Path.rootname() |> Path.split() |> Enum.take(-1)
    struct!(__MODULE__, [id: id, body: body] ++ Map.to_list(attrs))
  end
end

defmodule PremiereEcouteWeb.Static.Changelog do
  @moduledoc false

  use NimblePublisher,
    build: PremiereEcouteWeb.Static.Changelog.Entry,
    from: Application.app_dir(:premiere_ecoute, "priv/changelog/*.md"),
    as: :changelog,
    highlighters: [:makeup_elixir, :makeup_erlang]

  def all_entries, do: @changelog
  def get_entry(id), do: Enum.find(all_entries(), &(&1.id == id))
end
