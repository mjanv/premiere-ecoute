defmodule PremiereEcouteWeb.Twitch.History.MessagesSearchLive do
  @moduledoc """
  Search through Twitch chat messages from history export.
  """

  use PremiereEcouteWeb, :live_view

  require Explorer.DataFrame, as: DataFrame

  alias PremiereEcoute.Twitch.History.SiteHistory

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    file_path = Path.join("priv/static/uploads", "#{id}.zip")

    socket
    |> assign(:filename, id)
    |> assign(:file_path, file_path)
    |> assign(:search_query, "")
    |> assign(:search_results, [])
    |> assign(:total_results, 0)
    |> assign(:searching, false)
    |> assign_async(:messages, fn ->
      if File.exists?(file_path) do
        messages_df = SiteHistory.ChatMessages.read(file_path)
        {:ok, %{messages: %{df: messages_df}}}
      else
        {:error, "No file"}
      end
    end)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket = assign(socket, :search_query, query)

    if String.length(query) >= 3 do
      {:noreply, socket |> assign(:searching, true) |> perform_search(query)}
    else
      {:noreply, assign(socket, search_results: [], total_results: 0, searching: false)}
    end
  end

  defp perform_search(socket, query) do
    case socket.assigns.messages do
      %Phoenix.LiveView.AsyncResult{ok?: true, result: %{df: messages_df}} ->
        query_lower = String.downcase(query)

        results =
          messages_df
          |> DataFrame.to_rows()
          |> Enum.filter(fn msg ->
            body = msg["body"] || ""
            String.contains?(String.downcase(body), query_lower)
          end)
          |> Enum.sort_by(fn msg -> msg["time"] end, :desc)
          |> Enum.take(100)

        socket
        |> assign(:search_results, results)
        |> assign(:total_results, length(results))
        |> assign(:searching, false)

      _ ->
        assign(socket, searching: false)
    end
  end
end
