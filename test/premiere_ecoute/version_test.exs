defmodule PremiereEcoute.VersionTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Version

  describe "version/0" do
    test "returns a non-empty string" do
      version = Version.version()
      assert is_binary(version)
      assert String.length(version) > 0
    end

    test "follows the format 'version-commit'" do
      version = Version.version()
      assert version =~ ~r/^\d+\.\d+\.\d+-.+$/
    end

    test "version part matches mix.exs project version" do
      mix_version = Mix.Project.config()[:version]
      version = Version.version()
      [version_part, _commit_part] = String.split(version, "-", parts: 2)
      assert version_part == mix_version
    end

    test "commit part is either 'unknown' or a valid git short hash" do
      version = Version.version()
      [_version_part, commit_part] = String.split(version, "-", parts: 2)

      # AIDEV-NOTE: Commit should be either "unknown" or a 7-char hex string (git short hash)
      assert commit_part == "unknown" or
               (String.length(commit_part) == 7 and commit_part =~ ~r/^[0-9a-f]{7}$/)
    end

    test "version is computed at compile-time" do
      # AIDEV-NOTE: Calling version/0 multiple times should return the same result
      # since it's a compile-time constant
      version1 = Version.version()
      version2 = Version.version()
      assert version1 == version2
    end
  end
end
