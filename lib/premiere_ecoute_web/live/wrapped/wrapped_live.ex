defmodule PremiereEcouteWeb.Wrapped.WrappedLive do
  @moduledoc """
  Viewer Wrapped page.

  `:own` shows the recap of the logged-in viewer and waits for it when it is not computed yet, or asks a visitor to sign in with Twitch and brings them back, `:shared` replays a recap from its share token, `:admin` opens any stored recap by id, `:preview` is the public pixel render on sample cards, to collect feedback, `:demo` (dev only) plays sample cards with any render.
  """

  use PremiereEcouteWeb, :live_view
  use Gettext, backend: PremiereEcoute.Gettext

  import PremiereEcouteWeb.Wrapped.Stories

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Wrapped
  alias PremiereEcouteCore.FeatureFlag
  alias PremiereEcouteWeb.Wrapped.Renders

  @impl true
  def mount(params, _session, socket) do
    with {year, ""} <- Integer.parse(params["year"] || ""),
         true <- Wrapped.year?(year) do
      socket
      |> assign(year: year, page_title: "Wrapped #{year}", recap: nil, cards: [], owner: nil, share_url: nil)
      |> assign(:render, Renders.default())
      |> load(socket.assigns.live_action, params)
    else
      _ -> {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  defp load(socket, :own, params) do
    case socket.assigns[:current_scope] do
      %{user: %User{} = user} -> own(socket, user, params)
      _ -> {:ok, assign(socket, :state, :anonymous)}
    end
  end

  defp load(socket, :shared, %{"share_token" => token} = params) do
    with %{cards: [_ | _] = cards} = recap <- Wrapped.get_shared_recap(socket.assigns.year, token),
         %User{} = owner <- User.get(recap.user_id) do
      name = owner.username

      {:ok,
       socket
       |> assign(
         state: :ready,
         cards: cards,
         owner: name,
         page_title: gettext("%{name}'s Wrapped %{year}", name: name, year: recap.year)
       )
       |> assign(:og_image, url(~p"/wrapped/#{recap.year}/s/#{token}/card.svg"))
       |> assign_render(params, owner)
       |> assign_previews()}
    else
      _ -> {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  defp load(socket, :admin, %{"id" => id} = params) do
    year = socket.assigns.year

    case Integer.parse(id) do
      {id, ""} ->
        case Wrapped.fetch_recap(id) do
          %{year: ^year} = recap ->
            owner = User.get(recap.user_id)
            {:ok, socket |> assign(owner: owner.username) |> assign_render(params, owner) |> present(recap)}

          _ ->
            {:ok, push_navigate(socket, to: ~p"/admin/wrapped")}
        end

      _ ->
        {:ok, push_navigate(socket, to: ~p"/admin/wrapped")}
    end
  end

  # Public and without personal data: made-up listens over the latest albums, always played with the pixel render
  defp load(socket, :preview, _params) do
    year = socket.assigns.year

    {:ok,
     socket
     |> assign(state: :ready, cards: Wrapped.demo_cards(), share_url: url(~p"/wrapped/#{year}/preview"))
     |> assign(page_title: gettext("Wrapped %{year} preview", year: year), render: Renders.get(:pixel) || Renders.default())
     |> assign_previews()}
  end

  defp load(socket, :demo, params) do
    {:ok,
     socket
     |> assign(state: :ready, cards: Wrapped.demo_cards(), share_url: url(~p"/"))
     |> assign_render(params, nil)
     |> assign_previews()}
  end

  defp own(socket, user, params) do
    cond do
      not FeatureFlag.enabled?(:wrapped, for: user) ->
        {:ok, push_navigate(socket, to: ~p"/home")}

      is_nil(user.twitch) ->
        {:ok, assign(socket, :state, :no_twitch)}

      true ->
        if connected?(socket), do: PremiereEcoute.PubSub.subscribe(Wrapped.topic(user))
        recap = Wrapped.get_recap(user, socket.assigns.year)
        if is_nil(recap) and connected?(socket), do: Wrapped.request_recap(user, socket.assigns.year)

        {:ok, socket |> assign_render(params, user) |> present(recap || Wrapped.get_recap(user, socket.assigns.year))}
    end
  end

  # The render assigned to the owner of the recap, unless the visitor may pick one with `?render=`:
  # on the dev preview, on the admin replay, and for admins anywhere.
  defp assign_render(socket, params, owner) do
    override? = socket.assigns.live_action in [:demo, :admin] or admin?(socket.assigns[:current_scope])

    assign(socket, :render, Renders.select(param: params["render"], user: owner, override?: override?))
  end

  defp admin?(%{user: %User{role: :admin}}), do: true
  defp admin?(_scope), do: false

  defp present(socket, nil), do: assign(socket, :state, :waiting)
  defp present(socket, %{cards: []}), do: assign(socket, :state, :empty)

  defp present(socket, recap) do
    socket
    |> assign(state: :ready, recap: recap, cards: recap.cards)
    |> assign(:share_url, url(~p"/wrapped/#{recap.year}/s/#{recap.share_token}"))
    |> assign_previews()
  end

  # The player keeps its server-rendered markup (phx-update="ignore"), so previews are pushed to its hook
  # once the page is live rather than rendered as attributes.
  defp assign_previews(socket) do
    if connected?(socket),
      do: push_event(socket, "wrapped:previews", %{urls: Wrapped.previews(socket.assigns.cards)}),
      else: socket
  end

  @impl true
  def handle_info({:wrapped_computed, recap}, %{assigns: %{state: :waiting}} = socket), do: {:noreply, present(socket, recap)}
  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def handle_event("started", _params, %{assigns: %{live_action: :own, recap: %{} = recap}} = socket) do
    Wrapped.viewed(recap, socket.assigns.render.id)
    {:noreply, socket}
  end

  def handle_event("shared", _params, %{assigns: %{live_action: :own, recap: %{} = recap}} = socket) do
    Wrapped.shared(recap, socket.assigns.render.id)
    {:noreply, socket}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(%{state: :ready} = assigns) do
    ~H"""
    <Renders.player
      render={@render}
      year={@year}
      cards={@cards}
      owner={@owner}
      share_url={@share_url}
      exit_to={exit_to(@live_action)}
    />
    """
  end

  def render(assigns) do
    ~H"""
    <div class="wrapped wrapped-static">
      <div class="wrapped-stage">
        <section class="wrapped-card wrapped-start is-active">
          <.year year={@year} />
          <div :if={@state == :waiting} class="wrapped-waiting" role="status">
            <div class="wrapped-bars" aria-hidden="true"><i></i><i></i><i></i><i></i><i></i></div>
            <p class="wrapped-lead">{gettext("Putting your year together, it only takes a moment.")}</p>
          </div>
          <p :if={@state == :empty} class="wrapped-lead">
            {gettext("Not enough albums rated this year to make a Wrapped. See you in the chat for the next ones.")}
          </p>
          <p :if={@state == :anonymous} class="wrapped-lead">
            {gettext("Your Wrapped is built from your votes in Twitch chat. Sign in with Twitch to see it.")}
          </p>
          <.link
            :if={@state == :anonymous}
            href={~p"/auth/twitch?#{[role: "viewer", return_to: ~p"/wrapped/#{@year}"]}"}
            class="wrapped-cta"
          >
            {gettext("Continue with Twitch")}
          </.link>
          <p :if={@state == :no_twitch} class="wrapped-lead">
            {gettext("Your Wrapped is built from your votes in Twitch chat. Link your Twitch account to see it.")}
          </p>
          <.link :if={@state == :no_twitch} href={~p"/auth/twitch"} class="wrapped-cta">{gettext("Link Twitch")}</.link>
          <.link :if={@state == :empty} navigate={~p"/home"} class="wrapped-ghost">{gettext("Back to home")}</.link>
        </section>
      </div>
    </div>
    """
  end

  defp exit_to(:own), do: ~p"/home"
  defp exit_to(:admin), do: ~p"/admin/wrapped"
  defp exit_to(_action), do: ~p"/"
end
