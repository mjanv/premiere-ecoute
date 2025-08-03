defmodule PremiereEcouteWeb.Plugs.SetLocale do
  @moduledoc false

  import Plug.Conn

  @supported_locales Gettext.known_locales(PremiereEcoute.Gettext)

  def init(_options), do: nil

  def call(conn, _options) do
    # Check for locale in this priority order:
    # 1. URL params (for manual override)
    # 2. User profile language (if logged in)
    # 3. Cookies (fallback)
    locale =
      conn.params["locale"] ||
        get_user_profile_language(conn) ||
        conn.cookies["locale"]

    case locale do
      locale when locale in @supported_locales ->
        Gettext.put_locale(PremiereEcoute.Gettext, locale)

        conn
        |> put_resp_cookie("locale", locale, max_age: 365 * 24 * 60 * 60)
        |> put_session(:locale, locale)

      _ ->
        conn
    end
  end

  # Helper to get language from user profile
  defp get_user_profile_language(conn) do
    with %{current_scope: scope} when not is_nil(scope) <- conn.assigns,
         %{user: user} when not is_nil(user) <- scope,
         %{profile: profile} when not is_nil(profile) <- user,
         language when not is_nil(language) <- profile.language do
      Atom.to_string(language)
    else
      _ -> nil
    end
  end
end
