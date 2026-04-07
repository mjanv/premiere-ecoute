defmodule Mix.Tasks.Extension.Build do
  @moduledoc """
  Build the Twitch extension for distribution.

  This task runs webpack in production mode to compile and bundle the extension.

  ## Usage

      mix extension.build

  The built files will be output to `apps/extension/dist/`.
  """

  use Mix.Task
  use Boundary, classify_to: PremiereEcouteMix

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Building Twitch extension...")

    extension_dir = Path.join([File.cwd!(), "apps", "extension"])

    install!(extension_dir)

    case System.cmd("npm", ["run", "build"], cd: extension_dir, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info(output)
        package!(extension_dir)
        Mix.shell().info("Twitch extension built and packaged successfully")

      {output, exit_code} ->
        Mix.shell().error("Build failed with exit code #{exit_code}")
        Mix.shell().error(output)
        raise "Twitch extension build failed"
    end
  end

  defp package!(dir) do
    Mix.shell().info("Packaging extension as zip...")

    dist_dir = Path.join(dir, "dist")
    zip_path = Path.join(dir, "extension.zip")

    files =
      dist_dir
      |> File.ls!()
      |> Enum.map(&String.to_charlist/1)

    {:ok, _} = :zip.create(String.to_charlist(zip_path), files, cwd: String.to_charlist(dist_dir))

    Mix.shell().info("Packaged to apps/extension/extension.zip")
  end

  defp install!(dir) do
    Mix.shell().info("Installing npm dependencies...")

    case System.cmd("npm", ["install"], cd: dir, stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {output, exit_code} ->
        Mix.shell().error("npm install failed with exit code #{exit_code}")
        Mix.shell().error(output)
        raise "npm install failed"
    end
  end
end
