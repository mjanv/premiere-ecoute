defmodule PremiereEcouteWeb.Hooks.RestoreLocale do
  @moduledoc false

  @supported_locales Gettext.known_locales(PremiereEcoute.Gettext)

  def on_mount(_, params, session, socket) do
    # Check for locale in this priority order:
    # 1. URL params (for manual override)
    # 2. User profile language (if logged in)
    # 3. Session locale (fallback)
    locale =
      params["locale"] ||
        get_user_profile_language(socket) ||
        session["locale"] ||
        nil

    if locale in @supported_locales do
      Gettext.put_locale(PremiereEcoute.Gettext, locale)
    end

    {:cont, socket}
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
