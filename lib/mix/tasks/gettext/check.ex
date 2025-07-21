defmodule Mix.Tasks.Gettext.Check do
  use Mix.Task

  @shortdoc "Checks that all gettext strings are extracted and translated"
  @moduledoc """
  Runs gettext.extract, gettext.merge, and greps for missing translations.
  """

  @locales Application.compile_env(:premiere_ecoute, [PremiereEcouteWeb.Gettext, :locales])

  @impl true
  def run(_args) do
    Mix.Task.run("gettext.extract")

    for locale <- @locales do
      Mix.Task.run("gettext.merge", ["priv/gettext", "--locale", locale])
    end

    for locale <- ["fr", "it"] do
      file = "priv/gettext/#{locale}/LC_MESSAGES/default.po"
      Mix.shell().info("🔍 Checking for missing #{locale} translations in #{file}...")

      case System.cmd("grep", ["-B1", "msgstr \"\"", file]) do
        {output, 0} -> tl(String.split(output, "--"))
        _ -> []
      end
      |> case do
        [] ->
          Mix.shell().info("✅ No missing translations found.")

        translations ->
          Mix.shell().error("🔥 Missing translations found:\n" <> Enum.join(translations, "--"))
          exit({:shutdown, 1})
      end
    end
  end
end
