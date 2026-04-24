defmodule PremiereEcoute.Sessions.Scores.CommandHandler do
  @moduledoc """
  Command handler for chat commands.

  Handles !premiereecoute, !vote, and !save chat commands. Sends platform info, user vote averages, and saves the current track to a viewer's wantlist.
  """

  use PremiereEcouteCore.CommandBus.Handler

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Commands.Chat.SendChatCommand
  alias PremiereEcoute.Gettext
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcoute.Wantlists

  command(PremiereEcoute.Commands.Chat.SendChatCommand)

  @doc false
  def handle(%SendChatCommand{command: "premiereecoute", broadcaster_id: broadcaster_id, message_id: message_id}) do
    with broadcaster when not is_nil(broadcaster) <- Accounts.get_user_by_twitch_id(broadcaster_id),
         scope <- Scope.for_user(broadcaster),
         message <-
           Gettext.t(scope, fn ->
             gettext(
               "Premiere Ecoute is a platform where viewers can vote on music played during the stream. Register on premiere-ecoute.fr to view your votes!"
             )
           end) do
      send_reply(scope, message, message_id)
    else
      _ -> {:ok, []}
    end
  end

  def handle(%SendChatCommand{command: "vote", broadcaster_id: broadcaster_id, user_id: viewer_id, message_id: message_id}) do
    with broadcaster when not is_nil(broadcaster) <- Accounts.get_user_by_twitch_id(broadcaster_id),
         scope <- Scope.for_user(broadcaster),
         true <- Accounts.profile(broadcaster, [:chat_settings, :vote_enabled], true),
         session when not is_nil(session) <- ListeningSession.get_active_session(broadcaster),
         message when not is_nil(message) <- Vote.get_vote_message(session.id, viewer_id, session.vote_options) do
      send_reply(scope, message, message_id)
    else
      _ -> {:ok, []}
    end
  end

  def handle(%SendChatCommand{command: "save", broadcaster_id: broadcaster_id, user_id: viewer_twitch_id, message_id: message_id}) do
    with broadcaster when not is_nil(broadcaster) <- Accounts.get_user_by_twitch_id(broadcaster_id),
         scope <- Scope.for_user(broadcaster),
         true <- Accounts.profile(broadcaster, [:chat_settings, :save_wantlist], false),
         {:ok, %{"item" => %{"id" => id, "name" => name}}} when not is_nil(id) <-
           Apis.cache(:spotify).get_playback_state(scope, %{}) do
      case Accounts.get_user_by_twitch_id(viewer_twitch_id) do
        nil ->
          message =
            Gettext.t(scope, fn -> gettext("Track not saved. Register on premiere-ecoute.fr to save tracks to your wantlist!") end)

          send_reply(scope, message, message_id)

        viewer ->
          case Wantlists.add_radio_track(viewer.id, id) do
            {:ok, _} ->
              message = Gettext.t(scope, fn -> gettext("%{track_name} saved to your wantlist!", track_name: name) end)
              send_reply(scope, message, message_id)

            {:error, _} ->
              {:ok, []}
          end
      end
    else
      _ -> {:ok, []}
    end
  end

  def handle(_), do: {:ok, []}

  defp send_reply(scope, message, message_id) do
    case Apis.twitch().send_reply_message(scope, message, message_id) do
      :ok -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end
end
