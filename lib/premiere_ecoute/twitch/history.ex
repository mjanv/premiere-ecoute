defmodule PremiereEcoute.Twitch.History do
  @moduledoc false

  @type t() :: %__MODULE__{
          username: String.t(),
          user_id: String.t(),
          request_id: String.t(),
          start_time: DateTime.t(),
          end_time: DateTime.t()
        }

  defstruct [:username, :user_id, :request_id, :start_time, :end_time]

  alias PremiereEcouteCore.Zipfile

  @doc "Returns the absolute path to a specific uploaded file by ID."
  def file_path(%__MODULE__{request_id: request_id}), do: file_path(request_id)
  def file_path(id), do: Path.join([PremiereEcoute.uploads_dir(), "#{id}.zip"])

  def read(file) do
    file
    |> Zipfile.json("request/metadata.json")
    |> case do
      %{
        "Username" => username,
        "UserID" => user_id,
        "RequestID" => request_id,
        "StartTime" => start_time,
        "EndTime" => end_time
      } ->
        %__MODULE__{
          username: username,
          user_id: user_id,
          request_id: request_id,
          start_time: Timex.parse!(start_time, "{ISO:Extended:Z}"),
          end_time: Timex.parse!(end_time, "{ISO:Extended:Z}")
        }

      _ ->
        nil
    end
  end
end
