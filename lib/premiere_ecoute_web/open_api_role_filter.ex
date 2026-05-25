defmodule PremiereEcouteWeb.OpenApiRoleFilter do
  @moduledoc """
  Filters an OpenAPI spec to only include operations visible to a given role.

  Operations opt-in to role visibility via the `x-role` extension field.
  An operation with no `x-role` extension is visible to all roles.
  An operation with `x-role: ["streamer"]` is only visible to streamers.
  """

  @doc """
  Returns a filtered copy of `spec` where only operations allowed for `role` remain.

  Paths with no remaining operations are dropped entirely.
  """
  @spec filter(OpenApiSpex.OpenApi.t(), atom() | String.t()) :: OpenApiSpex.OpenApi.t()
  def filter(spec, role) do
    role = to_string(role)

    filtered_paths =
      Enum.reduce(spec.paths, %{}, fn {path, path_item}, acc ->
        filtered_item = filter_path_item(path_item, role)

        if filtered_item != %{} do
          Map.put(acc, path, filtered_item)
        else
          acc
        end
      end)

    %{spec | paths: filtered_paths}
  end

  @http_methods ~w(get put post delete options head patch trace)a

  defp filter_path_item(path_item, role) do
    filtered =
      Enum.reduce(@http_methods, path_item, fn method, item ->
        operation = Map.get(item, method)

        if keep_operation?(operation, role) do
          item
        else
          Map.put(item, method, nil)
        end
      end)

    if Enum.any?(@http_methods, &Map.get(filtered, &1)) do
      filtered
    else
      %{}
    end
  end

  defp keep_operation?(nil, _role), do: false

  defp keep_operation?(operation, role) do
    # AIDEV-NOTE: extensions is a map with string keys on OpenApiSpex.Operation structs; nil when no extensions set
    roles = (operation.extensions || %{}) |> Map.get("x-role", [])
    roles == [] or role == "admin" or role in roles
  end
end
