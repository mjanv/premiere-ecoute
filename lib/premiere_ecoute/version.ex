defmodule PremiereEcoute.Version do
  @moduledoc """
  Provides compile-time version information for the application.

  The version is constructed from the Mix project version and the current git commit hash.
  All values are computed at compile-time to avoid runtime overhead.
  """

  # AIDEV-NOTE: Extract version from mix.exs at compile-time
  @app_version Mix.Project.config()[:version]

  # AIDEV-NOTE: Get git commit hash at compile-time; fallback to "unknown" if git unavailable
  @git_commit case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) do
                {commit, 0} -> String.trim(commit)
                _ -> "unknown"
              end

  @full_version "#{@app_version}-#{@git_commit}"

  @doc """
  Returns the full version string in the format: "version-commit".

  ## Examples

      iex> PremiereEcoute.Version.version()
      "1.0.0-abc1234"

  """
  def version, do: @full_version
end
