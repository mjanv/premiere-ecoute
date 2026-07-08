defmodule PremiereEcouteWeb.Chat.HashtagBannerLive do
  @moduledoc """
  OBS scrolling banner overlay for hashtag chat messages.

  Displays `#hashtag <text>` viewer chat messages as a continuously scrolling ticker, fed live via
  PubSub and seeded from the in-memory hashtag cache. Not tied to an active listening session — any
  chat activity on the broadcaster's channel feeds the banner.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Sessions.Chat.HashtagMessage

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    user = Accounts.User.get_user_by_username(username)

    # AIDEV-NOTE: guard against nil user (unknown username) to prevent BadMapError on user.twitch
    if is_nil(user) do
      {:ok, redirect(socket, to: "/")}
    else
      mount_with_user(user, socket)
    end
  end

  defp mount_with_user(user, socket) do
    case user.twitch do
      nil ->
        {:ok, assign(socket, messages: [])}

      twitch ->
        if connected?(socket) do
          PremiereEcoute.PubSub.subscribe("hashtags:#{twitch.user_id}")
          :timer.send_interval(:timer.seconds(5), :prune_expired)
        end

        socket
        |> assign(:broadcaster_id, twitch.user_id)
        |> assign(:messages, HashtagMessage.list(twitch.user_id))
        |> then(fn socket -> {:ok, socket} end)
    end
  end

  @impl true
  def handle_info({:hashtag_message, entry}, %{assigns: %{messages: messages}} = socket) do
    {:noreply, assign(socket, :messages, messages ++ [entry])}
  end

  @impl true
  def handle_info(:prune_expired, %{assigns: %{messages: messages}} = socket) do
    cutoff = DateTime.add(DateTime.utc_now(), -HashtagMessage.ttl(), :millisecond)

    {:noreply, assign(socket, :messages, Enum.filter(messages, &(DateTime.compare(&1.inserted_at, cutoff) == :gt)))}
  end

  @impl true
  def handle_info(_event, socket), do: {:noreply, socket}
end
