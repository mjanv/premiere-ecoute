defmodule PremiereEcouteWeb.Hooks.RestoreLocale do
  @moduledoc false

  @supported_locales Gettext.known_locales(PremiereEcoute.Gettext)

  def on_mount(_, _params, session, socket) do
    # AIDEV-NOTE: Locale priority: browser language first, then user profile (if authenticated)
    locale = get_locale_from_browser_or_profile(socket, session)

    if locale in @supported_locales do
      Gettext.put_locale(PremiereEcoute.Gettext, locale)
    end

    {:cont, socket}
  end

  # Get locale from browser language first, then user profile for authenticated users
  defp get_locale_from_browser_or_profile(socket, session) do
    browser_locale = get_browser_locale(session)

    case get_user_profile_language(socket) do
      nil ->
        # Non-authenticated user: use browser locale only
        browser_locale

      profile_locale ->
        # Authenticated user: browser first, then profile as fallback
        profile_locale
    end
  end

  # Extract preferred locale from session (LiveView doesn't have direct access to headers)
  # The browser locale should have been set by the SetLocale plug and stored in session
  defp get_browser_locale(session) do
    # For LiveView, we rely on the session that was set by the SetLocale plug
    session["locale"]
  end

  # Helper to get language from user profile
  defp get_user_profile_language(socket) do
    with %{current_scope: scope} when not is_nil(scope) <- socket.assigns,
         %{user: user} when not is_nil(user) <- scope,
         %{profile: profile} when not is_nil(profile) <- user,
         language when not is_nil(language) <- profile.language do
      Atom.to_string(language)
    else
      _ -> nil
    end
  end
end
