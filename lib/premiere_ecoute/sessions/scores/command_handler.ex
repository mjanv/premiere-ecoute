defmodule PremiereEcoute.Sessions.Scores.CommandHandler do
  @moduledoc """
  Command handler for chat commands.

  Handles !premiereecoute and !vote chat commands, sending information about the platform or user's current average vote via Twitch chat replies.
  """

  use PremiereEcouteCore.CommandBus.Handler

  require Logger

  import Ecto.Query

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Commands.Chat.SendChatCommand
  alias PremiereEcoute.Gettext
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Vote

  command(PremiereEcoute.Commands.Chat.SendChatCommand)

  def handle(%SendChatCommand{command: "premiereecoute", broadcaster_id: broadcaster_id, message_id: message_id}) do
    with broadcaster when not is_nil(broadcaster) <- Accounts.get_user_by_twitch_id(broadcaster_id),
         scope <- Scope.for_user(broadcaster),
         message <-
           Gettext.t(scope, fn ->
             gettext(
               "Premiere Ecoute is a platform where viewers can vote on music played during the stream. Register on premiere-ecoute.fr to view your votes!"
             )
           end) do
      send_chat_reply(broadcaster_id, message_id, message)
    else
      _ -> {:ok, []}
    end
  end

  def handle(%SendChatCommand{command: "vote", broadcaster_id: broadcaster_id, user_id: viewer_id, message_id: message_id}) do
    with broadcaster when not is_nil(broadcaster) <- Accounts.get_user_by_twitch_id(broadcaster_id),
         session when not is_nil(session) <- get_active_session(broadcaster.id),
         message when not is_nil(message) <- get_vote_message(session.id, viewer_id, session.vote_options) do
      send_chat_reply(broadcaster_id, message_id, message)
    else
      _ -> {:ok, []}
    end
  end

  def handle(_), do: {:ok, []}

  defp send_chat_reply(broadcaster_id, message_id, message) do
    with broadcaster when not is_nil(broadcaster) <- Accounts.get_user_by_twitch_id(broadcaster_id),
         scope <- Scope.for_user(broadcaster),
         :ok <- Apis.twitch().send_reply_message(scope, message, message_id) do
      {:ok, []}
    else
      nil ->
        Logger.error("Cannot send chat reply due to unknown broadcaster")
        {:error, []}

      {:error, reason} ->
        Logger.error("Cannot send chat reply due to: #{inspect(reason)}")
        {:error, []}
    end
  end

  defp get_active_session(user_id) do
    from(s in ListeningSession,
      where: s.user_id == ^user_id and s.status == :active,
      order_by: [desc: s.updated_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp get_vote_message(session_id, viewer_id, vote_options) do
    from(v in Vote,
      where: v.session_id == ^session_id and v.viewer_id == ^viewer_id,
      select: avg(fragment("CAST(? AS FLOAT)", v.value))
    )
    |> Repo.one()
    |> case do
      nil -> nil
      avg -> "#{Float.round(avg, 1)}/#{List.last(vote_options)}"
    end
  end
end
