defmodule PremiereEcoute.Repo do
  use Ecto.Repo,
    otp_app: :premiere_ecoute,
    adapter: Ecto.Adapters.SQLite3
end
