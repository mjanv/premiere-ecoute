defmodule PremiereEcoute.Podcasts.Storage.Local do
  @moduledoc """
  Filesystem-backed storage adapter for development and tests.

  Writes objects under `priv/static/uploads/<key>` (served publicly by `Plug.Static` at `/uploads`),
  mirroring the existing image-upload pattern. Production swaps in an S3-compatible adapter; the
  behaviour keeps the rest of the app unchanged. Not suitable for multi-node / ephemeral hosts.
  """

  @behaviour PremiereEcoute.Podcasts.Storage

  import Plug.Conn

  @impl true
  def fetch(key) do
    case File.read(path(key)) do
      {:ok, bytes} -> {:ok, bytes}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def put(key, bytes) do
    dest = path(key)
    File.mkdir_p!(Path.dirname(dest))
    File.write(dest, bytes)
  end

  @impl true
  def delete(key) do
    _ = File.rm(path(key))
    :ok
  end

  @impl true
  def send_object(conn, key, content_type) do
    file = path(key)

    case File.stat(file) do
      {:ok, %File.Stat{size: size}} ->
        conn =
          conn
          |> put_resp_header("content-type", content_type)
          |> put_resp_header("accept-ranges", "bytes")

        case requested_range(conn, size) do
          {:partial, first, last} ->
            conn
            |> put_resp_header("content-range", "bytes #{first}-#{last}/#{size}")
            |> send_file(206, file, first, last - first + 1)

          :full ->
            send_file(conn, 200, file)

          :unsatisfiable ->
            conn
            |> put_resp_header("content-range", "bytes */#{size}")
            |> send_resp(416, "")
        end

      {:error, _} ->
        send_resp(conn, 404, "Not found")
    end
  end

  defp requested_range(conn, size) do
    case get_req_header(conn, "range") do
      [range | _] -> parse_range(range, size)
      [] -> :full
    end
  end

  # Single byte range: "bytes=first-last", "bytes=first-", or "bytes=-suffix".
  defp parse_range(range, size) do
    case Regex.run(~r/^bytes=(\d*)-(\d*)$/, range) do
      [_, "", ""] -> :full
      [_, "", suffix] -> clamp(size - String.to_integer(suffix), size - 1, size)
      [_, first, ""] -> clamp(String.to_integer(first), size - 1, size)
      [_, first, last] -> clamp(String.to_integer(first), String.to_integer(last), size)
      _ -> :full
    end
  end

  defp clamp(first, last, size) when first >= 0 and first <= last and first < size,
    do: {:partial, first, min(last, size - 1)}

  defp clamp(_first, _last, _size), do: :unsatisfiable

  defp path(key), do: Application.app_dir(:premiere_ecoute, Path.join("priv/static/uploads", key))
end
