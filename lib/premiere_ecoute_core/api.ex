defmodule PremiereEcouteCore.Api do
  @moduledoc """
  Base module for API client implementations.

  Provides a common interface for HTTP API clients using Req, including configuration management, request helpers, response handling with status validation, telemetry integration, and automatic token caching with client credentials flow. Modules using this behavior must implement their API-specific methods defined in the corresponding Behaviour module.

  ## Available Methods

  - `env/0` - Retrieves the entire API configuration
  - `env/1` - Retrieves a specific configuration key
  - `impl/0` - Returns the API implementation module
  - `url/1` - Retrieves a URL by key from the configuration
  - `new/1` - Creates a new Req request with telemetry attached
  - `get/2`, `post/2`, `put/2`, `patch/2`, `delete/2` - HTTP request methods
  - `handle/3` - Handles API responses with status validation and error handling
  - `token/1` - Retrieves or refreshes access tokens with caching
  """

  @doc """
  Injects API client functionality into using module.

  Generates configuration accessors, HTTP request methods, response handlers, and token management with caching. Requires :app and :api options.
  """
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(opts) do
    app = Keyword.get(opts, :app, :premiere_ecoute)
    api = Keyword.get(opts, :api)
    name = String.capitalize(Atom.to_string(api))

    quote do
      require Logger

      alias PremiereEcoute.Telemetry
      alias PremiereEcouteCore.Cache

      @behaviour __MODULE__.Behaviour

      @doc "Retrieves entire API configuration"
      @spec env() :: keyword()
      def env, do: Application.get_env(unquote(app), PremiereEcoute.Apis)

      @doc "Retrieves specific configuration key"
      @spec env(atom()) :: any()
      def env(key), do: Application.get_env(unquote(app), PremiereEcoute.Apis)[key]

      @doc "Returns API implementation module"
      @spec impl() :: module()
      def impl, do: env()[unquote(api)][:api]

      @doc "Retrieves URL by key from configuration"
      @spec url(atom()) :: String.t()
      def url(key), do: env()[unquote(api)][:urls][key]

      @doc "Creates new Req request with telemetry attached"
      @spec new(keyword()) :: Req.Request.t()
      def new(attrs) do
        attrs
        |> Keyword.merge(env(unquote(api))[:req_options] || [])
        |> Req.new()
        |> Telemetry.ReqPipeline.attach(unquote(api), &Telemetry.ApiMetrics.api_call/2)
      end

      @doc "Executes GET request"
      @spec get(Req.Request.t(), keyword()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
      def get(request, opts), do: Req.get(request, opts)

      @doc "Executes POST request"
      @spec post(Req.Request.t(), keyword()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
      def post(request, opts), do: Req.post(request, opts)

      @doc "Executes PUT request"
      @spec put(Req.Request.t(), keyword()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
      def put(request, opts), do: Req.put(request, opts)

      @doc "Executes PATCH request"
      @spec patch(Req.Request.t(), keyword()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
      def patch(request, opts), do: Req.patch(request, opts)

      @doc "Executes DELETE request"
      @spec delete(Req.Request.t(), keyword()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
      def delete(request, opts), do: Req.delete(request, opts)

      @doc "Handles API response with status validation and error handling"
      @spec handle({:ok, Req.Response.t()} | {:error, any()}, integer() | [integer()], (any() -> any())) ::
              {:ok, any()} | {:error, String.t()}
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

      @doc false
      def handle({:error, reason}, _, _) do
        Logger.error("#{unquote(name)} request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
      end

      @doc "Retrieves or refreshes access token with caching"
      @spec token(String.t() | nil) :: String.t()
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
