defmodule PremiereEcouteWeb.Static.Legal.Document do
  @moduledoc false

  @enforce_keys [:id, :version, :date, :language, :title, :body]
  defstruct [:id, :version, :date, :language, :title, :body]

  def build(filename, attrs, body) do
    [id] = filename |> Path.rootname() |> Path.split() |> Enum.take(-1)
    struct!(__MODULE__, [id: id, body: body] ++ Map.to_list(attrs))
  end
end

defmodule PremiereEcouteWeb.Static.Legal do
  @moduledoc false

  use NimblePublisher,
    build: PremiereEcouteWeb.Static.Legal.Document,
    from: Application.app_dir(:premiere_ecoute, "priv/legal/*.md"),
    as: :documents,
    highlighters: [:makeup_elixir, :makeup_erlang]

  def documents, do: @documents
  def document(id), do: Enum.find(documents(), &(&1.id == id))
end
