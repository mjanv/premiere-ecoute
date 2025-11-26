defmodule PremiereEcoute.Accounts.LegalDocument do
  @moduledoc """
  Legal document struct.

  Represents legal documents like privacy policy, cookies, and terms with versioning, language, and content loaded via NimblePublisher.
  """

  @enforce_keys [:id, :version, :date, :language, :title, :body]
  defstruct [:id, :version, :date, :language, :title, :body]

  def build(filename, attrs, body) do
    [id] = filename |> Path.rootname() |> Path.split() |> Enum.take(-1)
    struct!(__MODULE__, [id: id, body: body] ++ Map.to_list(attrs))
  end
end
