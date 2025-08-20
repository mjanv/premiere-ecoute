defmodule PremiereEcouteCore.Api do
  @moduledoc false

  defmacro __using__(opts) do
    app = Keyword.get(opts, :app, :premiere_ecoute)
    api = Keyword.get(opts, :api)
    name = String.capitalize(Atom.to_string(api))

    quote do
      require Logger

      alias PremiereEcoute.Telemetry
      alias PremiereEcouteCore.Cache

      @behaviour __MODULE__.Behaviour

      def env, do: Application.get_env(unquote(app), PremiereEcoute.Apis)
      def env(key), do: Application.get_env(unquote(app), PremiereEcoute.Apis)[key]
      def impl, do: env()[unquote(api)][:api]
      def url(key), do: env()[unquote(api)][:urls][key]

      def new(attrs) do
        attrs
        |> Keyword.merge(env(unquote(api))[:req_options] || [])
        |> Req.new()
        |> Telemetry.ReqPipeline.attach(unquote(api), &Telemetry.ApiMetrics.api_call/2)
      end

      def get(request, opts), do: Req.get(request, opts)
      def post(request, opts), do: Req.post(request, opts)
      def put(request, opts), do: Req.put(request, opts)
      def patch(request, opts), do: Req.patch(request, opts)
      def delete(request, opts), do: Req.delete(request, opts)

      def handle({:ok, %Req.Response{status: status, body: body} = r}, status_or_statuses, f) do
        if status in List.wrap(status_or_statuses) do
          try do
            {:ok, f.(body)}
          rescue
            error ->
              Logger.error("#{unquote(name)} API unexpected body: #{status} - #{inspect(body)}")
              {:error, "#{unquote(name)} API error: #{status}"}
          end
        else
          Logger.error("#{unquote(name)} API unexpected status: #{status} - #{inspect(body)}")
          {:error, "#{unquote(name)} API error: #{status}"}
        end
      end

      def handle({:error, reason}, _, _) do
        Logger.error("#{unquote(name)} request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
      end

      def token(token) do
        with {:ok, nil} <- {:ok, token},
             {:ok, nil} <- Cache.get(:tokens, unquote(api)),
             {:ok, %{"access_token" => token, "expires_in" => expires_in}} <- client_credentials() do
          Cache.put(:tokens, unquote(api), token, expire: expires_in * 1_000)
          token
        else
          {:ok, token} ->
            token

          {:error, reason} ->
            Logger.error("Cannot retrieve #{unquote(name)} access token due to #{inspect(reason)}")
            ""
        end
      end
    end
  end
end
