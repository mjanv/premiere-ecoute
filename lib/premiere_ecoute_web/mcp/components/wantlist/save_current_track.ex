defmodule PremiereEcouteWeb.Mcp.Components.Wantlist.SaveCurrentTrack do
  @moduledoc "Save the track currently playing on a broadcaster's stream to the authenticated user's wantlist"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Wantlists

  schema do
    field :broadcaster_twitch_id, :string, required: true
  end

  @impl true
  def execute(%{broadcaster_twitch_id: broadcaster_twitch_id}, %{assigns: %{current_user: user}} = frame) do
    with broadcaster when not is_nil(broadcaster) <- Accounts.get_user_by_twitch_id(broadcaster_twitch_id),
         {:ok, playback} <- Apis.cache(:spotify).get_playback_state(Scope.for_user(broadcaster), %{}),
         {:ok, spotify_id} <- current_track_id(playback),
         {:ok, _item} <- Wantlists.impl().add_radio_track(user.id, spotify_id) do
      {:reply, Response.text(Response.tool(), "Track saved to wantlist."), frame}
    else
      nil -> {:reply, Response.error(Response.tool(), "Broadcaster not found."), frame}
      :no_track -> {:reply, Response.error(Response.tool(), "No track currently playing."), frame}
      {:error, _} -> {:reply, Response.error(Response.tool(), "Track could not be saved."), frame}
    end
  end

  defp current_track_id(%PlaybackState{item: %{uri: "spotify:track:" <> id}}), do: {:ok, id}
  defp current_track_id(_), do: :no_track
end
