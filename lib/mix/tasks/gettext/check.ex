defmodule Mix.Tasks.Gettext.Check do
  use Mix.Task

  @shortdoc "Checks that all gettext strings are extracted and translated"
  @moduledoc """
  Runs gettext.extract, gettext.merge, and greps for missing translations.
  """

  @locales ["fr"]

  @impl true
  def run(_args) do
    Mix.shell().info("📤 Extracting translatable strings...")
    Mix.Task.run("gettext.extract")

    for locale <- @locales do
      Mix.shell().info("🔄 Merging translations for '#{locale}' locale...")
      Mix.Task.run("gettext.merge", ["priv/gettext", "--locale", locale])

      file = "priv/gettext/#{locale}/LC_MESSAGES/default.po"
      Mix.shell().info("🔍 Checking for missing #{locale} translations in #{file}...")

      case System.cmd("grep", ["-B1", "msgstr \"\"", file]) do
        {output, 0} -> tl(String.split(output, "--"))
        _ -> []
      end
      |> case do
        [] ->
          Mix.shell().info("✅ No missing translations found.")
          exit({:shutdown, 0})

        translations ->
          Mix.shell().error("🔥 Missing translations found:\n" <> Enum.join(translations, "--"))
          exit({:shutdown, 1})
      end
    end
  end
end
