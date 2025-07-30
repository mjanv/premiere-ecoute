defmodule PremiereEcouteWeb.Plugs.SetLocale do
  @moduledoc false

  import Plug.Conn

  @supported_locales Gettext.known_locales(PremiereEcoute.Gettext)

  def init(_options), do: nil

  def call(conn, _options) do
    case conn.params["locale"] || conn.cookies["locale"] do
      locale when locale in @supported_locales ->
        Gettext.put_locale(PremiereEcoute.Gettext, locale)

        conn
        |> put_resp_cookie("locale", locale, max_age: 365 * 24 * 60 * 60)
        |> put_session(:locale, locale)

      _ ->
        conn
    end
  end
end
