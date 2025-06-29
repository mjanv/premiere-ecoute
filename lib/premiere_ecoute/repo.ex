defmodule PremiereEcoute.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :premiere_ecoute,
    adapter: Ecto.Adapters.SQLite3

  def traverse_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
