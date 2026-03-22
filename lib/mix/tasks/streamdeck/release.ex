defmodule Mix.Tasks.Streamdeck.Release do
  @moduledoc """
  Build and package the Stream Deck plugin for distribution.

  This task:

  1. Builds the plugin with rollup (production)
  2. Packages it as a `.streamDeckPlugin` file using the Elgato CLI

  ## Usage

      mix streamdeck.release

  The packaged plugins will be created in `apps/streamdeck/`:
  - `com.maxime-janvier.premiere-ecoute-streamer.streamDeckPlugin`
  - `com.maxime-janvier.premiere-ecoute-viewer.streamDeckPlugin`
  """

  use Mix.Task
  use Boundary, classify_to: PremiereEcouteMix

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Building Stream Deck plugin...")

    streamdeck_dir = Path.join([File.cwd!(), "apps", "streamdeck"])

    case System.cmd("npm", ["run", "release"], cd: streamdeck_dir, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info(output)
        Mix.shell().info("Stream Deck plugin packaged successfully")

      {output, exit_code} ->
        Mix.shell().error("Release failed with exit code #{exit_code}")
        Mix.shell().error(output)
        raise "Stream Deck plugin release failed"
    end
  end
end
