defmodule PremiereEcoute.Podcasts.Storage.Seaweed do
  @moduledoc """
  Production storage adapter backed by SeaweedFS via its Filer HTTP API.

  Objects are written/read/deleted with plain HTTP against the Filer endpoint (`filer_url`),
  using `Req` — no S3 request signing or extra dependency. The Filer stores the raw `PUT` body at
  the object's key path (intermediate directories are created automatically) and serves `GET` with
  HTTP Range support, which podcast players require.

  Public reads are addressed separately by `Storage.public_url/1` (`public_base_url`), so the Filer
  can stay on a private network while a public host/CDN/reverse-proxy serves the files. Configure:

      config :premiere_ecoute, PremiereEcoute.Podcasts.Storage,
        adapter: PremiereEcoute.Podcasts.Storage.Seaweed,
        public_base_url: "https://podcasts.premiere-ecoute.fr"

      config :premiere_ecoute, PremiereEcoute.Podcasts.Storage.Seaweed,
        filer_url: "http://seaweedfs-filer:8888",
        # optional Req options, e.g. auth headers for a secured Filer:
        req_options: [headers: [{"authorization", "Bearer ..."}]]
  """

  @behaviour PremiereEcoute.Podcasts.Storage

  @impl true
  def fetch(key) do
    case Req.get(req(), url: url(key)) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:ok, %{status: status}} -> {:error, {:unexpected_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def put(key, bytes) do
    case Req.put(req(), url: url(key), body: bytes) do
      {:ok, %{status: status}} when status in [200, 201, 204] -> :ok
      {:ok, %{status: status}} -> {:error, {:unexpected_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(key) do
    # Treat a missing object as already-deleted so cleanup is idempotent.
    case Req.delete(req(), url: url(key)) do
      {:ok, %{status: status}} when status in [200, 202, 204, 404] -> :ok
      {:ok, %{status: status}} -> {:error, {:unexpected_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp url(key), do: filer_url() <> "/" <> String.trim_leading(key, "/")
  defp filer_url, do: config() |> Keyword.fetch!(:filer_url) |> String.trim_trailing("/")
  defp req, do: Req.new(Keyword.get(config(), :req_options, []))
  defp config, do: Application.get_env(:premiere_ecoute, __MODULE__, [])
end
