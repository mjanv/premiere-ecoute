defmodule PremiereEcoute.Gettext do
  @moduledoc """
  Internationalization (i18n) backend

  This module provides the Gettext backend for handling translations and
  localization throughout the application. It serves as the primary interface
  for translating user-facing text into multiple languages.

  ## Translation Files

  Translation files are located in `priv/gettext/` with the following structure:

  ```
  priv/gettext/
  ├── fr/LC_MESSAGES/default.po
  ├── it/LC_MESSAGES/default.po
  └── default.pot
  ```

  ## Usage

  ```heex
  <h1>{gettext("Welcome to PremiereEcoute")}</h1>
  <p>{gettext("Connect with %{platform}", platform: "Twitch")}</p>
  ```

  ## Translation Workflow

  1. **Extract**: Run `mix gettext.extract` to find new translatable strings
  2. **Merge**: Run `mix gettext.merge priv/gettext` to update .po files
  3. **Translate**: Edit .po files to add translations for each language
  4. **Compile**: Translations are compiled into the application at build time
  """

  use Gettext.Backend, otp_app: :premiere_ecoute

  def gettext(msgid) do
    Gettext.gettext(__MODULE__, msgid)
  end

  @doc "Gets the locale for the current process"
  @spec locale :: Gettext.locale()
  def locale, do: Gettext.get_locale(__MODULE__)
end
