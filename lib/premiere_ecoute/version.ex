defmodule PremiereEcoute.Version do
  @moduledoc """
  Provides compile-time version information for the application.

  The version is constructed from the Mix project version and the current git commit hash.
  All values are computed at compile-time to avoid runtime overhead.
  """

  # AIDEV-NOTE: Extract version from mix.exs at compile-time
  @app_version Mix.Project.config()[:version]

  # AIDEV-NOTE: Get git commit hash at compile-time; fallback to empty string if git unavailable
  @git_commit case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) do
                {commit, 0} ->
                  trimmed = String.trim(commit)
                  if trimmed == "", do: "", else: trimmed

                _ ->
                  ""
              end

  # AIDEV-NOTE: Build full version, omitting dash if no git commit available
  @full_version if @git_commit == "" do
                  @app_version
                else
                  "#{@app_version}-#{@git_commit}"
                end

  @doc """
  Returns the full version string in the format: "version-commit".

  When git is unavailable, returns just the version without commit suffix.

  ## Examples

      iex> PremiereEcoute.Version.version()
      "1.0.0-abc1234"

      # When git is unavailable:
      iex> PremiereEcoute.Version.version()
      "1.0.0"

  """
  def version, do: @full_version
end
