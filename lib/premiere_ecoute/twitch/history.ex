defmodule PremiereEcoute.Twitch.History do
  @moduledoc false

  @type t() :: %__MODULE__{
          username: String.t(),
          user_id: String.t(),
          history_id: String.t(),
          start_time: DateTime.t(),
          end_time: DateTime.t()
        }

  defstruct [:username, :user_id, :history_id, :start_time, :end_time]

  alias PremiereEcouteCore.Zipfile

  def read(file) do
    file
    |> Zipfile.json("request/metadata.json")
    |> case do
      %{
        "Username" => username,
        "UserID" => user_id,
        "RequestID" => history_id,
        "StartTime" => start_time,
        "EndTime" => end_time
      } ->
        %__MODULE__{
          username: username,
          user_id: user_id,
          history_id: history_id,
          start_time: Timex.parse!(start_time, "{ISO:Extended:Z}"),
          end_time: Timex.parse!(end_time, "{ISO:Extended:Z}")
        }

      _ ->
        nil
    end
  end
end
