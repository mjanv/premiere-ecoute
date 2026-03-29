defmodule PremiereEcouteWeb.Components.WikipediaDrawer do
  @moduledoc """
  Live component that combines the Drawer with a Wikipedia article summary.

  Mount it once per page. Trigger a lookup by calling `send_update/2` with a
  `query:` key from the parent LiveView's `handle_event/3`.

  ## Integration example

      <%!-- In the template --%>
      <.live_component module={WikipediaDrawer} id="wiki" />

      <span class="cursor-pointer hover:underline"
            phx-click="open_wikipedia"
            phx-value-query={@album.artist}>
        {@album.artist}
      </span>

      <%!-- In the LiveView --%>
      def handle_event("open_wikipedia", %{"query" => query}, socket) do
        send_update(WikipediaDrawer, id: "wiki", query: query)
        {:noreply, socket}
      end
  """

  use PremiereEcouteWeb, :live_component

  alias PremiereEcoute.Apis
  alias PremiereEcouteWeb.Components.Drawer

  @impl true
  def update(%{id: id} = assigns, socket) do
    socket
    |> assign(:id, id)
    |> assign(:status, :loading)
    |> assign(:result, nil)
    |> assign(:toc, nil)
    |> start_async(:fetch, fn ->
      with {:ok, query} <- to_query(assigns),
           {:ok, [page | _]} <- Apis.wikipedia().search(query),
           _ <- :timer.sleep(1_000),
           {:ok, summary} <- Apis.wikipedia().summary(page),
           _ <- :timer.sleep(1_000),
           {:ok, toc} <- Apis.wikipedia().table_of_contents(page) do
        {:ok, {summary, toc}}
      else
        {:error, :idle} -> {:error, :idle}
        _ -> {:error, :not_found}
      end
    end)
    |> then(fn socket -> {:ok, socket} end)
  end

  def update(assigns, socket) do
    socket
    |> assign(:id, assigns.id)
    |> assign_new(:status, fn -> :idle end)
    |> assign_new(:result, fn -> nil end)
    |> assign_new(:toc, fn -> nil end)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_async(:fetch, {:ok, {:ok, {summary, toc}}}, %{assigns: %{id: id}} = socket) do
    socket
    |> assign(:status, :ok)
    |> assign(:result, summary)
    |> assign(:toc, toc)
    |> push_event("wiki-drawer:open:#{drawer_id(id)}", %{})
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:fetch, {:ok, {:error, status}}, socket) when status in [:idle, :not_found] do
    {:noreply, assign(socket, :status, status)}
  end

  def handle_async(:fetch, _, socket) do
    {:noreply, assign(socket, :status, :error)}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :drawer_id, drawer_id(assigns.id))

    ~H"""
    <div id={@id} phx-hook="WikipediaDrawer" data-drawer-id={@drawer_id}>
      <%!-- Loading toast --%>
      <%= if @status == :loading do %>
        <div
          class="fixed bottom-6 right-6 z-50 flex items-center gap-2 px-4 py-2 rounded-lg text-sm text-gray-300"
          style="background-color: var(--color-dark-800); border: 1px solid var(--color-dark-700);"
        >
          <span class="loading loading-spinner loading-xs"></span> Looking up Wikipedia…
        </div>
      <% end %>

      <%!-- Not found toast --%>
      <%= if @status == :not_found do %>
        <div
          class="fixed bottom-6 right-6 z-50 px-4 py-2 rounded-lg text-sm text-gray-400"
          style="background-color: var(--color-dark-800); border: 1px solid var(--color-dark-700);"
        >
          No Wikipedia article found
        </div>
      <% end %>

      <Drawer.drawer id={@drawer_id}>
        <:header>
          <div class="flex items-center gap-3">
            <%= if @result && @result.thumbnail_url do %>
              <img src={@result.thumbnail_url} class="w-10 h-10 rounded object-cover flex-shrink-0" />
            <% end %>
            <div>
              <div class="text-white font-semibold">{if @result, do: @result.title, else: ""}</div>
              <%= if @result && @result.page_url do %>
                <a
                  href={@result.page_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-1 text-xs text-purple-400 hover:text-purple-300 transition-colors"
                >
                  Wikipedia
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
                    />
                  </svg>
                </a>
              <% else %>
                <div class="text-xs text-gray-500 font-normal">Wikipedia</div>
              <% end %>
            </div>
          </div>
        </:header>

        <div class="space-y-4 text-sm leading-relaxed">
          <%= case @status do %>
            <% :loading -> %>
              <div class="space-y-3 animate-pulse">
                <div class="h-3 bg-white/10 rounded w-full"></div>
                <div class="h-3 bg-white/10 rounded w-5/6"></div>
                <div class="h-3 bg-white/10 rounded w-4/6"></div>
                <div class="h-3 bg-white/10 rounded w-full"></div>
                <div class="h-3 bg-white/10 rounded w-3/4"></div>
              </div>
            <% :ok -> %>
              <p class="text-gray-300">{@result.extract}</p>
              <%= if @toc && @toc.sections != [] do %>
                <div
                  class="mt-4 pt-4"
                  style="border-top: 1px solid var(--color-dark-700);"
                >
                  <div class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">
                    Contents
                  </div>
                  <nav class="space-y-0.5">
                    <%= for section <- @toc.sections do %>
                      <a
                        href={"#{@result.page_url}##{section.anchor}"}
                        target="_blank"
                        rel="noopener noreferrer"
                        class={[
                          "block text-xs py-0.5 hover:text-purple-300 transition-colors truncate",
                          if(section.level == 1,
                            do: "text-gray-300 font-medium",
                            else: "text-gray-500 pl-4"
                          )
                        ]}
                      >
                        {section.number}&nbsp;{section.title}
                      </a>
                    <% end %>
                  </nav>
                </div>
              <% end %>
            <% :not_found -> %>
              <p class="text-gray-500">No Wikipedia article found.</p>
            <% :error -> %>
              <p class="text-gray-500">Could not load Wikipedia article. Try again later.</p>
            <% _ -> %>
          <% end %>
        </div>
      </Drawer.drawer>
    </div>
    """
  end

  defp drawer_id(id), do: "wiki-drawer-#{id}"

  defp to_query(%{artist: artist, album: album}), do: {:ok, [artist: artist, album: album]}
  defp to_query(%{artist: artist}), do: {:ok, [artist: artist]}
  defp to_query(_), do: {:error, :idle}
end
