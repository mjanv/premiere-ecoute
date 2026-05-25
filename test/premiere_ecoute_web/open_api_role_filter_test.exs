defmodule PremiereEcouteWeb.OpenApiRoleFilterTest do
  use ExUnit.Case, async: true

  alias OpenApiSpex.{OpenApi, Operation, PathItem}
  alias PremiereEcouteWeb.OpenApiRoleFilter

  defp operation(roles) when is_list(roles) do
    %Operation{responses: %{}, extensions: %{"x-role" => roles}}
  end

  defp operation(:public) do
    %Operation{responses: %{}, extensions: nil}
  end

  defp spec(paths) do
    %OpenApi{paths: paths, info: %OpenApiSpex.Info{title: "Test", version: "1"}}
  end

  describe "filter/2" do
    test "keeps operations matching the role" do
      spec =
        spec(%{
          "/session" => %PathItem{get: operation(["streamer"])}
        })

      result = OpenApiRoleFilter.filter(spec, :streamer)

      assert Map.has_key?(result.paths, "/session")
      assert result.paths["/session"].get != nil
    end

    test "drops operations for a different role" do
      spec =
        spec(%{
          "/session" => %PathItem{get: operation(["streamer"])}
        })

      result = OpenApiRoleFilter.filter(spec, :viewer)

      refute Map.has_key?(result.paths, "/session")
    end

    test "keeps operations with no x-role (public) for any role" do
      spec =
        spec(%{
          "/status" => %PathItem{get: operation(:public)}
        })

      for role <- [:streamer, :viewer, :admin] do
        result = OpenApiRoleFilter.filter(spec, role)
        assert Map.has_key?(result.paths, "/status"), "expected /status to be visible for #{role}"
      end
    end

    test "keeps operations visible to multiple roles" do
      spec =
        spec(%{
          "/vote" => %PathItem{post: operation(["streamer", "viewer"])}
        })

      assert Map.has_key?(OpenApiRoleFilter.filter(spec, :streamer).paths, "/vote")
      assert Map.has_key?(OpenApiRoleFilter.filter(spec, :viewer).paths, "/vote")
    end

    test "admin sees all operations regardless of x-role" do
      spec =
        spec(%{
          "/session" => %PathItem{get: operation(["streamer"])},
          "/vote" => %PathItem{post: operation(["streamer", "viewer"])},
          "/status" => %PathItem{get: operation(:public)}
        })

      result = OpenApiRoleFilter.filter(spec, :admin)

      assert Map.has_key?(result.paths, "/session")
      assert Map.has_key?(result.paths, "/vote")
      assert Map.has_key?(result.paths, "/status")
    end

    test "accepts role as a string" do
      spec =
        spec(%{
          "/session" => %PathItem{get: operation(["streamer"])}
        })

      result = OpenApiRoleFilter.filter(spec, "streamer")

      assert Map.has_key?(result.paths, "/session")
    end

    test "drops a path entirely when all its operations are filtered out" do
      spec =
        spec(%{
          "/session" => %PathItem{
            get: operation(["streamer"]),
            post: operation(["streamer"])
          }
        })

      result = OpenApiRoleFilter.filter(spec, :viewer)

      refute Map.has_key?(result.paths, "/session")
    end

    test "keeps a path when at least one operation matches" do
      spec =
        spec(%{
          "/session" => %PathItem{
            get: operation(["streamer"]),
            post: operation(["streamer", "viewer"])
          }
        })

      result = OpenApiRoleFilter.filter(spec, :viewer)

      assert Map.has_key?(result.paths, "/session")
      assert result.paths["/session"].get == nil
      assert result.paths["/session"].post != nil
    end

    test "preserves path item metadata (summary, description, parameters) when filtering" do
      spec =
        spec(%{
          "/session" => %PathItem{
            summary: "Session path",
            description: "Manages sessions",
            get: operation(["streamer"]),
            post: operation(["streamer", "viewer"])
          }
        })

      result = OpenApiRoleFilter.filter(spec, :viewer)
      path_item = result.paths["/session"]

      assert path_item.summary == "Session path"
      assert path_item.description == "Manages sessions"
    end

    test "handles empty paths map" do
      result = OpenApiRoleFilter.filter(spec(%{}), :streamer)

      assert result.paths == %{}
    end

    test "preserves spec-level fields unchanged" do
      spec = spec(%{"/x" => %PathItem{get: operation(["streamer"])}})

      result = OpenApiRoleFilter.filter(spec, :streamer)

      assert result.info == spec.info
    end
  end
end
