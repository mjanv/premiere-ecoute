defmodule PremiereEcouteWeb.Plugs.SetLocale do
  @moduledoc """
  Plug for setting user locale based on browser preferences and profile.

  Determines the locale from the Accept-Language header or authenticated user profile, sets it in Gettext, and stores it in session and cookies for supported locales.
  """

  import Plug.Conn

  @supported_locales Gettext.known_locales(PremiereEcoute.Gettext)

  def init(_options), do: nil

  def call(conn, _options) do
    case get_locale_from_browser_or_profile(conn) do
      locale when locale in @supported_locales ->
        Gettext.put_locale(PremiereEcoute.Gettext, locale)

        conn
        |> put_resp_cookie("locale", locale, max_age: 365 * 24 * 60 * 60)
        |> put_session(:locale, locale)

      _ ->
        conn
    end
  end

  # Get locale from browser language first, then user profile for authenticated users
  defp get_locale_from_browser_or_profile(conn) do
    browser_locale = get_browser_locale(conn)

    case get_user_profile_language(conn) do
      nil ->
        # Non-authenticated user: use browser locale only
        browser_locale

      profile_locale ->
        # Authenticated user: browser first, then profile as fallback
        browser_locale || profile_locale
    end
  end

  # Extract preferred locale from Accept-Language header
  defp get_browser_locale(conn) do
    case get_req_header(conn, "accept-language") do
      [accept_language | _] ->
        accept_language
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(fn lang ->
          # Extract language code (e.g., "en-US" -> "en", "fr;q=0.9" -> "fr")
          lang
          |> String.split(";")
          |> hd()
          |> String.split("-")
          |> hd()
        end)
        |> Enum.find(&(&1 in @supported_locales))

      _ ->
        nil
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
