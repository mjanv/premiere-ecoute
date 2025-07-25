defmodule PremiereEcoute.Accounts.Role do
  @moduledoc false

  @spec(map()) :: :admin | :bot | :streamer | :viewerr
  def role(auth_data) do
    case {auth_data.broadcaster_type, auth_data.username} do
      {_, "lanfeust313"} -> :admin
      {_, "premiereecoutebot"} -> :bot
      {"affiliate", _} -> :streamer
      {"partner", _} -> :streamer
      _ -> :viewer
    end
  end
end
