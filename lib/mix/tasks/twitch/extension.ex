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
    Logger.info("🚀 Building Twitch extension...")

    extension_dir = Path.join([File.cwd!(), "apps", "extension"])
    build_dir = Path.join(extension_dir, "dist")
    zip_file = Path.join(File.cwd!(), "twitch-extension.zip")

    # Ensure we're in the right directory
    unless File.exists?(extension_dir) do
      raise "Extension directory not found at #{extension_dir}"
    end

    # Step 1: Build the extension for production
    Logger.info("📦 Building extension for production...")
    build_extension(extension_dir)

    # Step 2: Copy manifest.json to build directory
    Logger.info("📝 Copying manifest.json...")
    update_manifest(extension_dir, build_dir)

    # Step 3: Create zip file
    Logger.info("📦 Creating zip file...")
    create_zip(build_dir, zip_file)

    Logger.info("✅ Twitch extension bundled successfully!")
    Logger.info("📁 Extension bundle: #{zip_file}")
    Logger.info("🔗 Upload this file to the Twitch Developer Console")
  end

  defp build_extension(extension_dir) do
    case System.cmd("npm", ["run", "build"], cd: extension_dir, stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Build completed successfully")
        Logger.debug(output)

      {output, exit_code} ->
        Logger.error("Build failed with exit code #{exit_code}")
        Logger.error(output)
        raise "Extension build failed"
    end
  end

  defp update_manifest(extension_dir, build_dir) do
    manifest_source = Path.join([extension_dir, "public", "manifest.json"])
    manifest_dest = Path.join(build_dir, "manifest.json")

    # Read and parse the manifest
    manifest_content = File.read!(manifest_source)
    manifest = Jason.decode!(manifest_content)

    # Keep viewer_url as viewer.html
    updated_manifest = manifest

    # Write updated manifest to build directory
    updated_content = Jason.encode!(updated_manifest, pretty: true)
    File.write!(manifest_dest, updated_content)

    Logger.info("Manifest copied to build directory")
  end

  defp create_zip(build_dir, zip_file) do
    # Remove existing zip file if it exists
    if File.exists?(zip_file) do
      File.rm!(zip_file)
    end

    # Get all files in the build directory (excluding the directory itself)
    files_to_zip =
      build_dir
      |> File.ls!()
      |> Enum.map(&Path.join(build_dir, &1))
      |> Enum.filter(&File.regular?/1)

    if Enum.empty?(files_to_zip) do
      raise "No files found in build directory"
    end

    # Create zip file with files (not the containing folder)
    case System.cmd("zip", ["-j", zip_file] ++ files_to_zip) do
      {_output, 0} ->
        Logger.info("Zip file created with #{length(files_to_zip)} files")

      {output, exit_code} ->
        Logger.error("Zip creation failed with exit code #{exit_code}")
        Logger.error(output)
        raise "Failed to create zip file"
    end

    # Verify the zip contents
    verify_zip_contents(zip_file)
  end

  defp verify_zip_contents(zip_file) do
    case System.cmd("unzip", ["-l", zip_file]) do
      {output, 0} ->
        Logger.info("Zip contents:")
        Logger.info(output)

        # Check that required files are present
        required_files = ["viewer.html", "manifest.json"]

        missing_files =
          Enum.reject(required_files, fn file ->
            String.contains?(output, file)
          end)

        if Enum.empty?(missing_files) do
          Logger.info("All required files present in zip")
        else
          Logger.warn("Missing required files: #{Enum.join(missing_files, ", ")}")
        end

      {output, exit_code} ->
        Logger.warn("Could not verify zip contents (exit code #{exit_code})")
        Logger.warn(output)
    end
  end
end
