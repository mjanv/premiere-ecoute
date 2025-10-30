defmodule PremiereEcoute.VersionTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Version

  describe "version/0" do
    test "returns a non-empty string" do
      version = Version.version()
      assert is_binary(version)
      assert String.length(version) > 0
    end

    test "follows valid version format" do
      version = Version.version()

      # AIDEV-NOTE: Format can be either "X.Y.Z" (no git) or "X.Y.Z-commit" (with git)
      assert version =~ ~r/^\d+\.\d+\.\d+(-[0-9a-f]{7})?$/
    end

    test "starts with mix.exs project version" do
      mix_version = Mix.Project.config()[:version]
      version = Version.version()

      # AIDEV-NOTE: Version should start with mix.exs version, may have "-commit" suffix
      assert String.starts_with?(version, mix_version)
    end

    test "when git is available, includes commit hash" do
      version = Version.version()

      # AIDEV-NOTE: If version contains a dash, commit should be a 7-char hex string
      if String.contains?(version, "-") do
        [_version_part, commit_part] = String.split(version, "-", parts: 2)
        assert String.length(commit_part) == 7
        assert commit_part =~ ~r/^[0-9a-f]{7}$/
      end
    end

    test "when git is unavailable, returns just the version" do
      # AIDEV-NOTE: This test documents the behavior when git is unavailable.
      # If the version doesn't contain a dash, it means git wasn't available at compile time
      version = Version.version()
      mix_version = Mix.Project.config()[:version]

      # Either it has a commit hash or it's just the version
      assert version == mix_version or String.starts_with?(version, "#{mix_version}-")
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
