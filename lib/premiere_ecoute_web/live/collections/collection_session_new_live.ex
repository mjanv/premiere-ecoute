defmodule PremiereEcouteWeb.Collections.CollectionSessionNewLive do
  @moduledoc """
  New collection session creation LiveView.

  Form to select origin and destination playlists.
  Dispatches PrepareCollectionSession then redirects to the session page.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Collections.CollectionSession.Commands.PrepareCollectionSession
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Twitch.RewardCatalog
  alias PremiereEcouteCore.CommandBus

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: scope}} = socket) do
    playlists = LibraryPlaylist.all_for_user(scope.user)

    socket
    |> assign(:playlists, playlists)
    |> assign(:rewards, [])
    |> assign(:catalog, RewardCatalog.list())
    |> assign(:form, to_form(default_form(), as: :session))
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_duel_reminder", _params, socket) do
    params = socket.assigns.form.params
    updated = Map.put(params, "duel_reminder_enabled", if(params["duel_reminder_enabled"] == "true", do: "false", else: "true"))
    {:noreply, assign(socket, :form, to_form(updated, as: :session))}
  end

  @impl true
  def handle_event("add_reward", _params, socket) do
    rewards = socket.assigns.rewards ++ [%{"title" => "", "cost" => "500", "prompt" => "", "is_user_input_required" => "false"}]
    {:noreply, assign(socket, :rewards, rewards)}
  end

  @impl true
  def handle_event("add_from_catalog", %{"id" => id}, socket) do
    case RewardCatalog.get(id) do
      nil ->
        {:noreply, socket}

      entry ->
        locale = Gettext.get_locale(PremiereEcoute.Gettext)

        reward = %{
          "title" => Map.get(entry.labels, locale, entry.title),
          "cost" => to_string(entry.cost),
          "prompt" => Map.get(entry.prompts, locale, entry.prompt),
          "is_user_input_required" => to_string(entry.is_user_input_required)
        }

        {:noreply, assign(socket, :rewards, socket.assigns.rewards ++ [reward])}
    end
  end

  @impl true
  def handle_event("remove_reward", %{"index" => index}, socket) do
    index = String.to_integer(index)
    rewards = List.delete_at(socket.assigns.rewards, index)
    {:noreply, assign(socket, :rewards, rewards)}
  end

  @impl true
  def handle_event("toggle_reward_input", %{"index" => index}, socket) do
    index = String.to_integer(index)

    rewards =
      List.update_at(socket.assigns.rewards, index, fn reward ->
        Map.put(reward, "is_user_input_required", if(reward["is_user_input_required"] == "true", do: "false", else: "true"))
      end)

    {:noreply, assign(socket, :rewards, rewards)}
  end

  @impl true
  def handle_event("validate", %{"session" => params}, socket) do
    merged = Map.merge(socket.assigns.form.params, params)
    rewards = sync_rewards(socket.assigns.rewards, params["rewards"] || %{})
    {:noreply, socket |> assign(:form, to_form(merged, as: :session)) |> assign(:rewards, rewards)}
  end

  @impl true
  def handle_event("submit", %{"session" => params}, %{assigns: %{current_scope: scope}} = socket) do
    rewards = sync_rewards(socket.assigns.rewards, params["rewards"] || %{})

    options =
      %{}
      |> then(fn opts ->
        if params["duel_reminder_enabled"] == "true",
          do: Map.put(opts, "duel_reminder_minutes", String.to_integer(params["duel_reminder_minutes"])),
          else: opts
      end)
      |> then(fn opts ->
        if params["duel_sound"] != "", do: Map.put(opts, "duel_sound", params["duel_sound"]), else: opts
      end)
      |> then(fn opts ->
        parsed =
          Enum.map(rewards, fn r ->
            %{
              "title" => r["title"],
              "cost" => parse_cost(r["cost"]),
              "prompt" => r["prompt"],
              "is_user_input_required" => r["is_user_input_required"] == "true"
            }
          end)
          |> Enum.reject(fn r -> r["title"] == "" end)

        if parsed == [], do: opts, else: Map.put(opts, "rewards", parsed)
      end)

    %PrepareCollectionSession{
      scope: scope,
      origin_playlist_id: parse_id(params["origin_playlist_id"]),
      destination_playlist_id: parse_id(params["destination_playlist_id"]),
      options: options
    }
    |> CommandBus.apply()
    |> case do
      {:ok, session, _events} ->
        {:noreply, push_navigate(socket, to: ~p"/collections/#{session.id}")}

      {:error, reason} ->
        socket
        |> put_flash(:error, gettext("Failed to create collection: %{reason}", reason: inspect(reason)))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  # Merges form input values back into the rewards list, preserving toggle state.
  defp sync_rewards(rewards, params) do
    rewards
    |> Enum.with_index()
    |> Enum.map(fn {reward, i} ->
      input = params[to_string(i)] || %{}
      Map.merge(reward, Map.take(input, ["title", "cost", "prompt"]))
    end)
  end

  defp default_form do
    %{
      "origin_playlist_id" => "",
      "destination_playlist_id" => "",
      "duel_reminder_enabled" => "false",
      "duel_reminder_minutes" => "30",
      "duel_sound" => ""
    }
  end

  defp parse_id(""), do: nil
  defp parse_id(nil), do: nil
  defp parse_id(val) when is_binary(val), do: String.to_integer(val)
  defp parse_id(val) when is_integer(val), do: val

  defp parse_cost(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> 500
    end
  end

  defp parse_cost(val) when is_integer(val), do: val
end
