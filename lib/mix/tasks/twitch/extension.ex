defmodule Mix.Tasks.Twitch.Extension do
  @moduledoc """
  Bundle the Twitch extension for upload to Twitch Developer Console.

  This task:
  1. Builds the extension for production with inlined JavaScript
  2. Updates the manifest.json to use index.html (required by Twitch)
  3. Creates a zip file ready for upload

  ## Usage

      mix twitch.extension

  The bundled extension will be created as `twitch-extension.zip` in the project root.
  """

  use Mix.Task

  require Logger

  @shortdoc "Bundle Twitch extension for upload"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("🚀 Building Twitch extension...")

    extension_dir = Path.join([File.cwd!(), "apps", "extension"])
    build_dir = Path.join(extension_dir, "dist")
    zip_file = Path.join(File.cwd!(), "twitch-extension.zip")

    # Step 1: Build the extension for production
    build_extension(extension_dir)

    # Step 2: Copy manifest.json to build directory
    update_manifest(extension_dir, build_dir)

    # Step 3: Create zip file
    create_zip(build_dir, zip_file)

    Mix.shell().info("✅ Twitch extension bundled successfully to #{zip_file}")
  end

  defp build_extension(extension_dir) do
    case System.cmd("npm", ["run", "build"], cd: extension_dir, stderr_to_stdout: true) do
      {_, 0} ->
        Mix.shell().info("📦 Build completed successfully")

      {output, exit_code} ->
        Mix.shell().error("Build failed with exit code #{exit_code}")
        Mix.shell().error(output)
        raise "Extension build failed"
    end
  end

  defp update_manifest(extension_dir, build_dir) do
    source = Path.join([extension_dir, "public", "manifest.json"])
    dest = Path.join(build_dir, "manifest.json")

    source
    |> File.read!()
    |> Jason.decode!()
    |> Jason.encode!(pretty: true)
    |> then(fn manifest -> File.write!(dest, manifest) end)
  end

  defp create_zip(build_dir, zip_file) do
    if File.exists?(zip_file), do: File.rm!(zip_file)

    files =
      build_dir
      |> File.ls!()
      |> Enum.map(&Path.join(build_dir, &1))
      |> Enum.filter(&File.regular?/1)

    case System.cmd("zip", ["-j", zip_file] ++ files) do
      {_output, 0} ->
        Mix.shell().info("📦 Zip file created with #{length(files)} files")

      {output, exit_code} ->
        Mix.shell().error("Zip creation failed with exit code #{exit_code}")
        Mix.shell().error(output)
        raise "Failed to create zip file"
    end
  end
end
