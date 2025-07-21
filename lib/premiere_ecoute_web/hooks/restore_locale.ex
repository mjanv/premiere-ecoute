defmodule PremiereEcouteWeb.Hooks.RestoreLocale do
  @moduledoc false

  @supported_locales Gettext.known_locales(PremiereEcouteWeb.Gettext)

  def on_mount(_, params, session, socket) do
    locale = params["locale"] || session["locale"] || nil

    if locale in @supported_locales do
      Gettext.put_locale(PremiereEcouteWeb.Gettext, locale)
    end

    {:cont, socket}
  end
end
