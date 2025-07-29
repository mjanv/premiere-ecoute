defmodule PremiereEcoute.Accounts.Services.AccountCompliance do
  @moduledoc false

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.EventStore
  alias PremiereEcoute.Sessions.Scores.Vote

  @spec download_associated_data(Scope.t()) :: {:ok, map()}
  def download_associated_data(scope) do
    user = User.preload(scope.user)
    votes = Vote.all(where: [viewer_id: user.twitch_user_id])
    events = EventStore.read("user-#{scope.user.id}", :raw)

    %{
      metadata: %{
        generated_at: DateTime.utc_now(),
        host: System.get_env("PHX_HOST", "localhost"),
        version: to_string(Application.spec(:premiere_ecoute)[:vsn])
      },
      data: %{profile: scope.user, activity: %{follows: user.channels, votes: votes}},
      events: events
    }
    |> Jason.encode!()
    |> Jason.decode!()
    |> anonym(["data", "activity", "follows"], ["twitch_user_id", "twitch_username"])
    |> anonym(["data", "activity", "votes"], ["session_id", "track_id", "value", "inserted_at"])
    |> Jason.encode!()
    |> then(fn data -> {:ok, data} end)
  end

  defp anonym(data, path, keys) do
    update_in(data, path, fn channels -> channels |> Enum.map(&Map.take(&1, keys)) end)
  end
end
