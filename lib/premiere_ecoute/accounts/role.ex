defmodule PremiereEcoute.Accounts.Role do
  @moduledoc false

  @spec from_auth(map()) :: :admin | :bot | :streamer | :viewer
  def from_auth(auth_data) do
    case {auth_data.broadcaster_type, auth_data.username} do
      {_, "lanfeust313"} -> :admin
      {_, "premiereecoutebot"} -> :bot
      {"affiliate", _} -> :streamer
      {"partner", _} -> :streamer
      _ -> :viewer
    end
  end
end
