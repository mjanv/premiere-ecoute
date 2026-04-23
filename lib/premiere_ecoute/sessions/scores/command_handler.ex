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
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcoute.Wantlists
  alias PremiereEcouteCore.Cache

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
      send_chat_reply(broadcaster_id, message_id, message)
    else
      _ -> {:ok, []}
    end
  end

  def handle(%SendChatCommand{command: "vote", broadcaster_id: broadcaster_id, user_id: viewer_id, message_id: message_id}) do
    with broadcaster when not is_nil(broadcaster) <- Accounts.get_user_by_twitch_id(broadcaster_id),
         true <- Accounts.profile(broadcaster, [:chat_settings, :vote_enabled], true),
         session when not is_nil(session) <- ListeningSession.get_active_session(broadcaster.id),
         message when not is_nil(message) <- Vote.get_vote_message(session.id, viewer_id, session.vote_options) do
      send_chat_reply(broadcaster_id, message_id, message)
    else
      _ -> {:ok, []}
    end
  end

  def handle(%SendChatCommand{command: "save", broadcaster_id: broadcaster_id, user_id: viewer_twitch_id, message_id: message_id}) do
    with broadcaster when not is_nil(broadcaster) <- Accounts.get_user_by_twitch_id(broadcaster_id),
         true <- Accounts.profile(broadcaster, [:chat_settings, :save_wantlist], false),
         {:ok, %{"item" => %{"id" => spotify_id, "name" => track_name}} = _state} when not is_nil(spotify_id) <-
           Cache.get(:playback, broadcaster.id) do
      case Accounts.get_user_by_twitch_id(viewer_twitch_id) do
        nil ->
          message =
            Gettext.t(Scope.for_user(broadcaster), fn ->
              gettext("Track not saved. Register on premiere-ecoute.fr to save tracks to your wantlist!")
            end)

          send_chat_reply(broadcaster_id, message_id, message)

        viewer ->
          case Wantlists.add_radio_track(viewer.id, spotify_id) do
            {:ok, _} ->
              message =
                Gettext.t(Scope.for_user(broadcaster), fn ->
                  gettext("%{track_name} saved to your wantlist!", track_name: track_name)
                end)

              send_chat_reply(broadcaster_id, message_id, message)

            {:error, _} ->
              {:ok, []}
          end
      end
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
end
