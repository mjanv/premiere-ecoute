defmodule PremiereEcouteWeb.Explorer.ExploreLive do
  @moduledoc """
  Music Explorer LiveView — the /explore route.

  Manages the question-first entry, node graph state, and keeps list.
  The canvas itself is rendered by a React Flow JS component (via the ExploreCanvas hook).

  Data flow:
  - User submits a query → `start_async(:resolve, ...)` → resolves entity, fetches node, annotates
  - Result pushed to JS canvas via `push_event("canvas:init", ...)` (first node)
    or `push_event("canvas:node_added", ...)` (subsequent nodes)
  - User clicks a hotspot → `handle_event("open_node", ...)` → same flow, pushes new node+edge
  - Keeps list stored in socket assigns; synced to React via `push_event("keeps:updated", ...)`
  """

  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Explorer.Services.AnnotateCards
  alias PremiereEcoute.Explorer.Services.FetchNode
  alias PremiereEcoute.Explorer.Services.ResolveQuery

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Explore")
    |> assign(:query, "")
    |> assign(:loading, false)
    |> assign(:error, nil)
    |> assign(:node_ids, [])
    |> assign(:keeps, [])
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("search", %{"query" => query}, socket) when byte_size(query) > 0 do
    socket =
      socket
      |> assign(:query, query)
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> assign(:node_ids, [])
      |> assign(:keeps, [])

    {:noreply, start_async(socket, :resolve, fn -> resolve_and_fetch(query) end)}
  end

  def handle_event("search", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("open_node", %{"entity_type" => type, "entity_id" => id_str, "parent_id" => parent_id}, socket) do
    # Prevent opening the same node twice.
    node_id = "#{type}-#{id_str}"

    if node_id in socket.assigns.node_ids do
      {:noreply, socket}
    else
      socket = assign(socket, :loading, true)

      {:noreply,
       start_async(socket, {:open_node, node_id, parent_id}, fn ->
         fetch_by_type_and_id(type, id_str)
       end)}
    end
  end

  @impl true
  def handle_event("keeps:add", %{"entity_type" => type, "entity_id" => id, "label" => label}, socket) do
    item = %{entity_type: type, entity_id: id, label: label}

    keeps =
      [item | socket.assigns.keeps]
      |> Enum.uniq_by(&{&1.entity_type, &1.entity_id})

    socket = assign(socket, :keeps, keeps)
    {:noreply, push_event(socket, "keeps:updated", %{keeps: keeps})}
  end

  @impl true
  def handle_event("keeps:remove", %{"entity_type" => type, "entity_id" => id}, socket) do
    keeps = Enum.reject(socket.assigns.keeps, &(&1.entity_type == type && &1.entity_id == id))
    socket = assign(socket, :keeps, keeps)
    {:noreply, push_event(socket, "keeps:updated", %{keeps: keeps})}
  end

  @impl true
  def handle_async(:resolve, {:ok, {:ok, node}}, socket) do
    node_data = serialize_node(node)

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:node_ids, [node_data.id])
      |> push_event("canvas:init", %{nodes: [node_data], edges: []})

    {:noreply, socket}
  end

  def handle_async(:resolve, {:ok, {:error, reason}}, socket) do
    Logger.warning("Explorer resolve failed: #{inspect(reason)}")
    {:noreply, assign(socket, loading: false, error: error_message(reason))}
  end

  def handle_async(:resolve, {:exit, reason}, socket) do
    Logger.error("Explorer resolve crashed: #{inspect(reason)}")
    {:noreply, assign(socket, loading: false, error: "Something went wrong. Please try again.")}
  end

  def handle_async({:open_node, node_id, parent_id}, {:ok, {:ok, node}}, socket) do
    node_data = serialize_node(node)
    edge = %{id: "#{parent_id}-#{node_data.id}", source: parent_id, target: node_data.id}

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:node_ids, [node_id | socket.assigns.node_ids])
      |> push_event("canvas:node_added", %{node: node_data, edge: edge})

    {:noreply, socket}
  end

  def handle_async({:open_node, _node_id, _parent_id}, {:ok, {:error, reason}}, socket) do
    Logger.warning("Explorer open_node failed: #{inspect(reason)}")
    {:noreply, assign(socket, loading: false, error: error_message(reason))}
  end

  def handle_async({:open_node, _node_id, _parent_id}, {:exit, _reason}, socket) do
    {:noreply, assign(socket, loading: false, error: "Could not load node. Please try again.")}
  end

  # --- Private helpers ---

  defp resolve_and_fetch(query) do
    with {:ok, entity} <- ResolveQuery.resolve(query),
         {:ok, node} <- FetchNode.fetch(entity),
         {:ok, annotated} <- AnnotateCards.annotate(node) do
      {:ok, annotated}
    end
  end

  defp fetch_by_type_and_id("artist", id_str) do
    alias PremiereEcoute.Discography.Artist

    case Integer.parse(id_str) do
      {id, ""} ->
        case Artist.get(id) do
          nil -> {:error, :not_found}
          artist -> resolve_and_fetch_entity({:artist, artist})
        end

      _ ->
        {:error, :invalid_id}
    end
  end

  defp fetch_by_type_and_id("album", id_str) do
    alias PremiereEcoute.Discography.Album

    case Integer.parse(id_str) do
      {id, ""} ->
        case Album.get(id) do
          nil -> {:error, :not_found}
          album -> resolve_and_fetch_entity({:album, album})
        end

      _ ->
        {:error, :invalid_id}
    end
  end

  defp fetch_by_type_and_id("track", id_str) do
    alias PremiereEcoute.Discography.Album.Track

    case Integer.parse(id_str) do
      {id, ""} ->
        case PremiereEcoute.Repo.get(Track, id) do
          nil -> {:error, :not_found}
          track -> resolve_and_fetch_entity({:track, track})
        end

      _ ->
        {:error, :invalid_id}
    end
  end

  # AIDEV-NOTE: "query" type comes from <i> hotspots in Wikipedia section HTML —
  # the entity_id is the raw text label, resolved the same way as a search query.
  defp fetch_by_type_and_id("query", query) do
    resolve_and_fetch(query)
  end

  defp fetch_by_type_and_id(_type, _id), do: {:error, :unknown_type}

  defp resolve_and_fetch_entity(entity) do
    with {:ok, node} <- FetchNode.fetch(entity),
         {:ok, annotated} <- AnnotateCards.annotate(node) do
      {:ok, annotated}
    end
  end

  # Serialize a Node struct to a plain map for JSON serialization via push_event.
  defp serialize_node(node) do
    %{
      id: node.id,
      entity_type: node.entity_type,
      entity_id: node.entity_id,
      entity_slug: node.entity_slug,
      label: node.label,
      subtitle: node.subtitle,
      thumbnail_url: node.thumbnail_url,
      provider_ids: node.provider_ids,
      cards:
        Enum.map(node.cards, fn card ->
          %{
            id: card.id,
            type: card.type,
            title: card.title,
            content_html: card.content_html
          }
        end)
    }
  end

  defp error_message(:not_found), do: "No results found. Try a different name."
  defp error_message(:wikipedia_not_found), do: "Could not find this on Wikipedia."
  defp error_message(_), do: "Something went wrong. Please try again."
end
