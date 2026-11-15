defmodule PremiereEcouteWeb.Wrapped.ShareCardController do
  @moduledoc """
  Serves the share card of a Wrapped as a 1080×1920 SVG built from its public recap card.

  The SVG is the template of the share image: rasterising it to PNG (for Open Graph previews) is still to be plugged in.
  """

  use PremiereEcouteWeb, :controller
  use Gettext, backend: PremiereEcoute.Gettext

  alias PremiereEcoute.Wrapped

  @fallback ["#6d28d9", "#db2777", "#1e1b4b"]

  @doc "Renders the share card of the recap behind a share token."
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"year" => year, "share_token" => token}) do
    with {year, ""} <- Integer.parse(year),
         %{cards: cards} <- Wrapped.get_shared_recap(year, token),
         %{} = card <- Enum.find(cards, &(&1["type"] == "recap")) do
      conn
      |> put_resp_content_type("image/svg+xml")
      |> put_resp_header("cache-control", "public, max-age=86400")
      |> send_resp(200, svg(card, year))
    else
      _ -> send_resp(conn, 404, "not found")
    end
  end

  @doc "Builds the share card SVG of a recap card."
  @spec svg(map(), integer()) :: String.t()
  def svg(card, year) do
    [c1, c2, c3] = Enum.take((card["appearance"]["colors"] || []) ++ @fallback, 3)

    rows =
      card["data"]["top"]
      |> Enum.with_index()
      |> Enum.map(fn {album, index} ->
        y = 640 + index * 250

        """
        <text x="90" y="#{y + 120}" font-size="150" font-weight="700" fill="#fff" fill-opacity="0.35">#{index + 1}</text>
        <text x="220" y="#{y + 70}" font-size="62" font-weight="700" fill="#fff">#{label(album["name"], 24)}</text>
        <text x="220" y="#{y + 135}" font-size="44" fill="#fff" fill-opacity="0.75">#{label(album["artist"], 30)}</text>
        <text x="990" y="#{y + 100}" font-size="72" font-weight="700" fill="#fff" text-anchor="end">#{:erlang.float_to_binary(album["score"] / 1, decimals: 1)}</text>
        """
      end)

    minutes =
      if card["data"]["minutes"] > 0 do
        """
        <text x="560" y="1560" font-size="150" font-weight="700" fill="#fff">#{card["data"]["minutes"]}</text>
        <text x="560" y="1620" font-size="44" fill="#fff" fill-opacity="0.75">#{label(ngettext("minute", "minutes", card["data"]["minutes"]), 40)}</text>
        """
      else
        ""
      end

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1920" viewBox="0 0 1080 1920" font-family="'Bricolage Grotesque', sans-serif">
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#{c1}"/><stop offset="0.55" stop-color="#{c2}"/><stop offset="1" stop-color="#{c3}"/>
        </linearGradient>
        <linearGradient id="shade" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#0b0a12" stop-opacity="0.25"/><stop offset="1" stop-color="#0b0a12" stop-opacity="0.8"/>
        </linearGradient>
      </defs>
      <rect width="1080" height="1920" fill="url(#bg)"/>
      <rect width="1080" height="1920" fill="url(#shade)"/>
      <text x="90" y="200" font-size="44" fill="#fff" fill-opacity="0.75">Premiere Ecoute Wrapped</text>
      <text x="90" y="470" font-size="300" font-weight="700" fill="#fff" letter-spacing="-12">#{year}</text>
      #{rows}
      <text x="90" y="1560" font-size="150" font-weight="700" fill="#fff">#{card["data"]["albums"]}</text>
      <text x="90" y="1620" font-size="44" fill="#fff" fill-opacity="0.75">#{label(ngettext("album", "albums", card["data"]["albums"]), 20)}</text>
      #{minutes}
      <text x="90" y="1800" font-size="40" fill="#fff" fill-opacity="0.6">premiere-ecoute.fr</text>
    </svg>
    """
  end

  defp label(nil, _max), do: ""

  defp label(value, max) do
    value = if String.length(value) > max, do: String.slice(value, 0, max - 1) <> "…", else: value
    value |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end
end
