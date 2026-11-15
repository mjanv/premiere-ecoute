defmodule PremiereEcouteWeb.Wrapped.PixelStories do
  @moduledoc """
  Markup of the pixel render of a Wrapped.

  The whole show is drawn on one canvas by the `WrappedPlayerPixel` hook (posters whose pictures and figures are made of pixels, under real type), so the server only sends the cards as data (covers through the image proxy), the translated labels, and the controls. A plain list of what the cards say is kept for screen readers.
  """

  use Phoenix.Component
  use Gettext, backend: PremiereEcoute.Gettext
  use PremiereEcouteWeb, :verified_routes

  import PremiereEcouteWeb.Components.Images, only: [proxy_url: 1]
  import PremiereEcouteWeb.CoreComponents, only: [icon: 1]

  alias PremiereEcouteWeb.Wrapped.Stories

  attr :year, :integer, required: true
  attr :cards, :list, required: true, doc: "cards of a recap, as stored (string keys)"
  attr :owner, :string, default: nil, doc: "name of the viewer, on a shared replay"
  attr :share_url, :string, default: nil, doc: "public URL of the recap, for its owner"
  attr :exit_to, :string, default: "/"
  attr :render, :map, default: %{id: :pixel, hook: "WrappedPlayerPixel"}, doc: "render playing the cards: its id and its JS hook"

  @spec stories(map()) :: Phoenix.LiveView.Rendered.t()
  def stories(assigns) do
    assigns = assign(assigns, pixels: Enum.map(assigns.cards, &pixel/1), labels: labels())

    ~H"""
    <div
      id="wrapped-player"
      class="wrapped-pixel"
      phx-hook={@render.hook}
      phx-update="ignore"
      data-render={@render.id}
      data-year={@year}
      data-owner={@owner}
      data-share-url={@share_url}
      data-cards={Jason.encode!(@pixels)}
      data-labels={Jason.encode!(@labels)}
    >
      <div class="wrapped-pixel-stage">
        <canvas class="wrapped-pixel-screen" data-screen aria-hidden="true"></canvas>

        <header class="wrapped-pixel-bar">
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

        <ol class="sr-only">
          <li :for={line <- Enum.flat_map(@cards, &summary/1)}>{line}</li>
        </ol>

        <button type="button" class="wrapped-pixel-button wrapped-pixel-begin" data-begin>{gettext("Start")}</button>

        <div class="wrapped-pixel-actions" data-actions hidden>
          <button :if={@share_url} type="button" class="wrapped-pixel-button" data-share data-copied={gettext("Link copied")}>
            {gettext("Share")}
          </button>
          <.link :if={!@share_url} navigate={~p"/wrapped/#{@year}"} class="wrapped-pixel-button">{gettext("See yours")}</.link>
          <button type="button" class="wrapped-pixel-button wrapped-pixel-ghost" data-replay>{gettext("Replay")}</button>
        </div>

        <button type="button" class="wrapped-pixel-tap wrapped-pixel-tap-prev" data-prev hidden aria-label={gettext("Previous")}></button>
        <button type="button" class="wrapped-pixel-tap wrapped-pixel-tap-next" data-next hidden aria-label={gettext("Next")}></button>
      </div>
    </div>
    """
  end

  # A card as the hook draws it: its type and its data, with covers served by the image proxy
  defp pixel(card) do
    %{type: card["type"], data: card |> Map.get("data", %{}) |> proxied() |> sessions()}
  end

  defp proxied(%{} = map),
    do: Map.new(map, fn {key, value} -> {key, if(key == "cover_url", do: proxy_url(value), else: proxied(value))} end)

  defp proxied(list) when is_list(list), do: Enum.map(list, &proxied/1)
  defp proxied(value), do: value

  # Plurals are resolved here: the hook only draws text
  defp sessions(%{"rooms" => rooms} = data) do
    Map.put(
      data,
      "rooms",
      Enum.map(rooms, &Map.put(&1, "label", ngettext("%{count} session", "%{count} sessions", &1["sessions"])))
    )
  end

  defp sessions(data), do: data

  defp labels do
    %{
      album: ngettext("album", "albums", 1),
      albums: ngettext("album", "albums", 2),
      minute: ngettext("minute", "minutes", 1),
      minutes: ngettext("minute", "minutes", 2),
      months: Enum.map(1..12, &Stories.month/1),
      tagline: gettext("Your year in music"),
      own_way: gettext("Where you went your own way"),
      same_thing: gettext("Where you heard the same thing"),
      every_cover: gettext("Every cover, in order"),
      busiest_month: gettext("Your busiest month"),
      where_listened: gettext("Where you listened"),
      started_with: gettext("It started with"),
      album_of_year: gettext("Your album of the year"),
      right_behind: gettext("Right behind"),
      track_of_year: gettext("Your track of the year"),
      more_tracks: gettext("More tracks you loved"),
      single_of_year: gettext("Your single of the year"),
      you: gettext("You"),
      chat: gettext("The chat"),
      intro: intro()
    }
  end

  defp intro do
    [
      gettext("A year of albums heard live with the chat on Premiere Ecoute"),
      gettext("Here is what you listened to, what you loved, and what you bring home.")
    ]
  end

  # What a card says, in words
  defp summary(%{"type" => "year_in_music", "data" => data}) do
    [
      "#{data["albums"]} #{ngettext("album", "albums", data["albums"])}, #{data["minutes"]} #{ngettext("minute", "minutes", data["minutes"])}"
    ]
  end

  defp summary(%{"type" => "cover_wall", "data" => %{"covers" => covers}}),
    do: [gettext("Every cover, in order") <> ": " <> Enum.map_join(covers, ", ", &named/1)]

  defp summary(%{"type" => "your_months", "data" => data}),
    do: [gettext("Your busiest month") <> ": " <> Stories.month(data["busiest"])]

  defp summary(%{"type" => "your_rooms", "data" => %{"rooms" => rooms}}) do
    [
      gettext("Where you listened") <>
        ": " <>
        Enum.map_join(rooms, ", ", &"#{&1["name"]} (#{ngettext("%{count} session", "%{count} sessions", &1["sessions"])})")
    ]
  end

  defp summary(%{"type" => "first_vote", "data" => data}),
    do: [gettext("It started with") <> ": " <> named(data["album"]) <> ", " <> data["date"]]

  defp summary(%{"type" => "top_album", "data" => %{"album" => album}}),
    do: [gettext("Your album of the year") <> ": " <> scored(album)]

  defp summary(%{"type" => "top_track", "data" => %{"track" => track}}),
    do: [gettext("Your track of the year") <> ": " <> scored(track)]

  defp summary(%{"type" => "top_single", "data" => %{"single" => single}}),
    do: [gettext("Your single of the year") <> ": " <> scored(single)]

  defp summary(%{"type" => "next_albums", "data" => %{"albums" => albums}}),
    do: [gettext("Right behind") <> ": " <> Enum.map_join(albums, ", ", &scored/1)]

  defp summary(%{"type" => "next_tracks", "data" => %{"tracks" => tracks}}),
    do: [gettext("More tracks you loved") <> ": " <> Enum.map_join(tracks, ", ", &scored/1)]

  defp summary(%{"type" => "you_and_chat", "data" => data}) do
    [
      gettext("Where you went your own way") <> ": " <> versus(data["furthest"]),
      gettext("Where you heard the same thing") <> ": " <> versus(data["closest"])
    ]
  end

  defp summary(%{"type" => "recap", "data" => %{"top" => top}}), do: Enum.map(top, &named/1)
  defp summary(_card), do: []

  defp named(%{"name" => name, "artist" => artist}) when is_binary(artist), do: "#{name} — #{artist}"
  defp named(%{"name" => name}), do: name

  defp scored(entry), do: "#{named(entry)}, #{format(entry["score"])}"

  defp versus(entry),
    do: "#{named(entry)}, #{gettext("You")} #{format(entry["you"])}, #{gettext("The chat")} #{format(entry["chat"])}"

  defp format(value), do: :erlang.float_to_binary(value / 1, decimals: 1)
end
