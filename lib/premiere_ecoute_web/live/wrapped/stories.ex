defmodule PremiereEcouteWeb.Wrapped.Stories do
  @moduledoc """
  Story player of a Wrapped: a start screen and one full-screen section per card.

  Everything is rendered once; the JS hook of the render (`WrappedPlayer` by default) drives playback in the browser. Elements marked `data-in` are animated in when their card opens, `data-count` rolls a number, `data-grow` scales a bar.
  """

  use Phoenix.Component
  use Gettext, backend: PremiereEcoute.Gettext
  use PremiereEcouteWeb, :verified_routes

  import PremiereEcouteWeb.Components.Images, only: [proxy_url: 1]
  import PremiereEcouteWeb.CoreComponents, only: [icon: 1]

  @max_covers 60

  attr :year, :integer, required: true
  attr :cards, :list, required: true, doc: "cards of a recap, as stored (string keys)"
  attr :owner, :string, default: nil, doc: "name of the viewer, on a shared replay"
  attr :share_url, :string, default: nil, doc: "public URL of the recap, for its owner"
  attr :exit_to, :string, default: "/"
  attr :render, :map, default: %{id: :classic, hook: "WrappedPlayer"}, doc: "render playing the cards: its id and its JS hook"

  @spec stories(map()) :: Phoenix.LiveView.Rendered.t()
  def stories(assigns) do
    ~H"""
    <div
      id="wrapped-player"
      class="wrapped"
      phx-hook={@render.hook}
      phx-update="ignore"
      data-render={@render.id}
      data-share-url={@share_url}
    >
      <canvas class="wrapped-bg" data-bg aria-hidden="true"></canvas>
      <div class="wrapped-grain" aria-hidden="true"></div>

      <div class="wrapped-stage">
        <ol class="wrapped-progress" aria-hidden="true">
          <li :for={_ <- @cards}><span data-progress></span></li>
        </ol>

        <header class="wrapped-bar">
          <span class="wrapped-brand">Premiere Ecoute</span>
          <button type="button" data-pause hidden aria-label={gettext("Pause")} aria-pressed="false">
            <span data-icon-pause><.icon name="hero-pause-solid" /></span>
            <span data-icon-play hidden><.icon name="hero-play-solid" /></span>
          </button>
          <button type="button" data-mute hidden aria-label={gettext("Mute")} aria-pressed="false">
            <span data-icon-sound><.icon name="hero-speaker-wave-solid" /></span>
            <span data-icon-muted hidden><.icon name="hero-speaker-x-mark-solid" /></span>
          </button>
          <.link navigate={@exit_to} aria-label={gettext("Close")}><.icon name="hero-x-mark-solid" /></.link>
        </header>

        <section class="wrapped-card wrapped-start is-active" data-start>
          <p :if={@owner} class="wrapped-label">{@owner}</p>
          <.year year={@year} />
          <p :if={!@owner} class="wrapped-lead">
            {gettext("A year of albums heard live and rated in the chat, one vote at a time.")}
          </p>
          <p :if={!@owner} class="wrapped-lead">
            {gettext("Here is what you listened to, what you loved, and where you and the chat disagreed.")}
          </p>
          <p :if={@owner} class="wrapped-lead">
            {gettext(
              "A year of albums heard live and rated in the chat: what they listened to, what they loved, and where they and the chat disagreed."
            )}
          </p>
          <button type="button" class="wrapped-cta" data-begin>{gettext("Start")}</button>
        </section>

        <section
          :for={card <- @cards}
          class={"wrapped-card wrapped-#{String.replace(card["type"], "_", "-")}"}
          data-card
          data-type={card["type"]}
          data-colors={Jason.encode!(card["appearance"]["colors"] || [])}
          aria-hidden="true"
        >
          <.card card={card} year={@year} owner={@owner} share_url={@share_url} />
        </section>

        <button type="button" class="wrapped-tap wrapped-tap-prev" data-prev hidden aria-label={gettext("Previous")}></button>
        <button type="button" class="wrapped-tap wrapped-tap-next" data-next hidden aria-label={gettext("Next")}></button>
      </div>
    </div>
    """
  end

  @doc "The year as a two-line poster title."
  attr :year, :integer, required: true
  attr :rest, :global

  @spec year(map()) :: Phoenix.LiveView.Rendered.t()
  def year(assigns) do
    ~H"""
    <h1 class="wrapped-year" aria-label={@year} {@rest}>
      <span aria-hidden="true">{div(@year, 100)}</span>
      <span aria-hidden="true">{@year |> rem(100) |> Integer.to_string() |> String.pad_leading(2, "0")}</span>
    </h1>
    """
  end

  attr :card, :map, required: true
  attr :year, :integer, required: true
  attr :owner, :string, default: nil
  attr :share_url, :string, default: nil

  defp card(%{card: %{"type" => "year_in_music"}} = assigns) do
    ~H"""
    <.figure value={@card["data"]["albums"]} label={ngettext("album", "albums", @card["data"]["albums"])} />
    <.figure
      :if={@card["data"]["minutes"] > 0}
      value={@card["data"]["minutes"]}
      label={ngettext("minute", "minutes", @card["data"]["minutes"])}
      outline
    />
    """
  end

  defp card(%{card: %{"type" => "cover_wall"}} = assigns) do
    covers = Enum.take(assigns.card["data"]["covers"], @max_covers)
    columns = columns(length(covers))

    assigns =
      assigns
      |> assign(:covers, covers)
      |> assign(:columns, columns)
      |> assign(:fillers, rem(columns - rem(length(covers), columns), columns))

    ~H"""
    <h2 class="sr-only">{gettext("Every cover, in order")}</h2>
    <div class="wrapped-wall-tilt">
      <ul class="wrapped-wall" style={"--cols: #{@columns}"} data-drift>
        <li :for={cover <- @covers} data-in="cover">
          <img src={proxy_url(cover["cover_url"])} alt={"#{cover["name"]} — #{cover["artist"]}"} loading="eager" draggable="false" />
        </li>
        <li :for={_ <- 1..@fillers//1} class="wrapped-wall-empty" data-in="cover" aria-hidden="true"></li>
      </ul>
    </div>
    """
  end

  defp card(%{card: %{"type" => "your_months"}} = assigns) do
    assigns = assign(assigns, :peak, Enum.max(assigns.card["data"]["months"]))

    ~H"""
    <h2 class="wrapped-label" data-in="up">{gettext("Your busiest month")}</h2>
    <p class="wrapped-shout" data-in="slam">{month(@card["data"]["busiest"])}</p>
    <ol class="wrapped-months" aria-label={gettext("Albums per month")}>
      <li
        :for={{count, index} <- Enum.with_index(@card["data"]["months"], 1)}
        class={index == @card["data"]["busiest"] && "is-busiest"}
      >
        <b :if={count > 0} data-in="up">{count}</b>
        <i style={"height: #{max(round(count / @peak * 100), 2)}%"} data-in="bar"></i>
        <span aria-label={month(index)}>{index |> month() |> String.first()}</span>
      </li>
    </ol>
    """
  end

  defp card(%{card: %{"type" => "your_rooms"}} = assigns) do
    ~H"""
    <h2 class="wrapped-label" data-in="up">{gettext("Where you listened")}</h2>
    <ol class="wrapped-rooms">
      <li :for={room <- @card["data"]["rooms"]} data-in="left">
        <b>{room["name"]}</b>
        <span>{ngettext("%{count} session", "%{count} sessions", room["sessions"])}</span>
      </li>
    </ol>
    """
  end

  defp card(%{card: %{"type" => "first_vote"}} = assigns) do
    assigns = assign(assigns, :date, Date.from_iso8601!(assigns.card["data"]["date"]))

    ~H"""
    <h2 class="wrapped-label" data-in="up">{gettext("It started with")}</h2>
    <.hero cover_url={@card["data"]["album"]["cover_url"]} />
    <.name album={@card["data"]["album"]} class="wrapped-name-hero" data-in="up" />
    <p class="wrapped-date" data-in="up">{@date.day} {month(@date.month)}</p>
    """
  end

  defp card(%{card: %{"type" => "top_album"}} = assigns) do
    ~H"""
    <h2 class="wrapped-label" data-in="up">{gettext("Your album of the year")}</h2>
    <.hero cover_url={@card["data"]["album"]["cover_url"]} score={@card["data"]["album"]["score"]} rank />
    <.name album={@card["data"]["album"]} class="wrapped-name-hero" data-in="up" />
    """
  end

  defp card(%{card: %{"type" => "next_albums"}} = assigns) do
    ~H"""
    <h2 class="wrapped-label" data-in="up">{gettext("Right behind")}</h2>
    <.runners entries={@card["data"]["albums"]} />
    """
  end

  defp card(%{card: %{"type" => "top_track"}} = assigns) do
    ~H"""
    <h2 class="wrapped-label" data-in="up">{gettext("Your track of the year")}</h2>
    <.hero cover_url={@card["data"]["track"]["cover_url"]} score={@card["data"]["track"]["score"]} rank />
    <.name album={@card["data"]["track"]} class="wrapped-name-hero" data-in="up" />
    """
  end

  defp card(%{card: %{"type" => "next_tracks"}} = assigns) do
    ~H"""
    <h2 class="wrapped-label" data-in="up">{gettext("More tracks you loved")}</h2>
    <.runners entries={@card["data"]["tracks"]} />
    """
  end

  defp card(%{card: %{"type" => "top_single"}} = assigns) do
    ~H"""
    <h2 class="wrapped-label" data-in="up">{gettext("Your single of the year")}</h2>
    <.hero cover_url={@card["data"]["single"]["cover_url"]} score={@card["data"]["single"]["score"]} />
    <.name album={@card["data"]["single"]} class="wrapped-name-hero" data-in="up" />
    """
  end

  defp card(%{card: %{"type" => "you_and_chat"}} = assigns) do
    ~H"""
    <h2 class="sr-only">{gettext("You and the chat")}</h2>
    <.versus glyph="≠" label={gettext("Where you went your own way")} entry={@card["data"]["furthest"]} />
    <.versus glyph="=" label={gettext("Where you heard the same thing")} entry={@card["data"]["closest"]} />
    """
  end

  defp card(%{card: %{"type" => "recap"}} = assigns) do
    ~H"""
    <p :if={@owner} class="wrapped-label" data-in="up">{@owner}</p>
    <.year year={@year} data-in="up" />
    <div class="wrapped-fan">
      <img
        :for={{album, index} <- Enum.with_index(@card["data"]["top"])}
        src={proxy_url(album["cover_url"])}
        alt=""
        loading="eager"
        draggable="false"
        data-in="fan"
        data-rotate={Enum.at([0, -11, 9], index)}
      />
    </div>
    <ol class="wrapped-top" data-in="up">
      <li :for={album <- @card["data"]["top"]}><b>{album["name"]}</b> <span>{album["artist"]}</span></li>
    </ol>
    <dl class="wrapped-stats" data-in="up">
      <div>
        <dd>{@card["data"]["albums"]}</dd>
        <dt>{ngettext("album", "albums", @card["data"]["albums"])}</dt>
      </div>
      <div :if={@card["data"]["minutes"] > 0}>
        <dd>{@card["data"]["minutes"]}</dd>
        <dt>{ngettext("minute", "minutes", @card["data"]["minutes"])}</dt>
      </div>
    </dl>
    <div class="wrapped-actions" data-in="up">
      <button :if={@share_url} type="button" class="wrapped-cta" data-share data-copied={gettext("Link copied")}>
        {gettext("Share")}
      </button>
      <.link :if={!@share_url} navigate={~p"/wrapped/#{@year}"} class="wrapped-cta">{gettext("See yours")}</.link>
      <button type="button" class="wrapped-ghost" data-replay>{gettext("Replay")}</button>
    </div>
    """
  end

  # Recaps stored with a card this version does not know still play
  defp card(assigns), do: ~H""

  attr :cover_url, :string, default: nil
  attr :score, :float, default: nil
  attr :rank, :boolean, default: false

  # One cover thrown onto the card, its score bursting out of the corner
  defp hero(assigns) do
    ~H"""
    <div class="wrapped-hero" data-in="hero">
      <img src={proxy_url(@cover_url)} alt="" loading="eager" draggable="false" />
      <span :if={@rank} class="wrapped-hero-rank" aria-hidden="true">1</span>
      <.score :if={@score} value={@score} class="wrapped-hero-score" />
    </div>
    """
  end

  attr :entries, :list, required: true, doc: "albums or tracks ranked from 2"

  defp runners(assigns) do
    ~H"""
    <ol class="wrapped-runners" start="2">
      <li :for={{entry, rank} <- Enum.with_index(@entries, 2)} data-in="left">
        <span class="wrapped-rank" aria-hidden="true">{rank}</span>
        <img src={proxy_url(entry["cover_url"])} alt="" loading="eager" draggable="false" />
        <.name album={entry} />
        <.score value={entry["score"]} />
      </li>
    </ol>
    """
  end

  attr :value, :integer, required: true
  attr :label, :string, required: true
  attr :outline, :boolean, default: false

  # A number as large as the stage allows: the size follows its digit count
  defp figure(assigns) do
    assigns = assign(assigns, :digits, assigns.value |> Integer.digits() |> length() |> max(2))

    ~H"""
    <p class={["wrapped-figure", @outline && "wrapped-figure-outline"]} style={"--digits: #{@digits}"}>
      <b data-in="slam"><span data-count>{@value}</span></b>
      <small data-in="up">{@label}</small>
    </p>
    """
  end

  attr :album, :map, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  defp name(assigns) do
    ~H"""
    <p class={["wrapped-name", @class]} {@rest}>
      <b>{@album["name"]}</b>
      <span>{@album["artist"]}</span>
    </p>
    """
  end

  attr :glyph, :string, required: true
  attr :label, :string, required: true
  attr :entry, :map, required: true

  defp versus(assigns) do
    ~H"""
    <article class="wrapped-versus">
      <h3 class="sr-only">{@label}</h3>
      <img src={proxy_url(@entry["cover_url"])} alt="" loading="eager" draggable="false" data-in="hero" />
      <.name album={@entry} data-in="up" />
      <dl class="wrapped-duel" data-in="up">
        <div>
          <dd>{format(@entry["you"])}</dd>
          <dt>{gettext("You")}</dt>
        </div>
        <div class="wrapped-glyph" aria-hidden="true">{@glyph}</div>
        <div class="wrapped-duel-chat">
          <dd>{format(@entry["chat"])}</dd>
          <dt>{gettext("The chat")}</dt>
        </div>
      </dl>
    </article>
    """
  end

  attr :value, :float, required: true
  attr :class, :string, default: nil

  defp score(assigns) do
    ~H"""
    <span class={["wrapped-score", @class]}>{format(@value)}</span>
    """
  end

  @doc "Name of a month, from 1 to 12."
  @spec month(1..12) :: String.t()
  def month(1), do: gettext("January")
  def month(2), do: gettext("February")
  def month(3), do: gettext("March")
  def month(4), do: gettext("April")
  def month(5), do: gettext("May")
  def month(6), do: gettext("June")
  def month(7), do: gettext("July")
  def month(8), do: gettext("August")
  def month(9), do: gettext("September")
  def month(10), do: gettext("October")
  def month(11), do: gettext("November")
  def month(12), do: gettext("December")

  defp format(value), do: :erlang.float_to_binary(value / 1, decimals: 1)

  defp columns(count) when count <= 6, do: 2
  defp columns(count) when count <= 18, do: 3
  defp columns(count) when count <= 36, do: 4
  defp columns(_count), do: 5
end
