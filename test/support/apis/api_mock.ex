defmodule PremiereEcoute.ApiMock do
  @moduledoc """
  API mocking utilities for tests.

  Provides helpers to mock HTTP API responses using Req.Test, with support for request validation and response stubbing.
  """

  import ExUnit.Assertions

  @doc """
  Sets up expectation for mock HTTP request with validation.

  Configures Req.Test to expect a specific number of requests with path, method, headers, params, and body validation, returning stubbed response.
  """
  @spec expect(atom(), keyword()) :: :ok
  def expect(module, opts \\ []) do
    Req.Test.expect(module, Keyword.get(opts, :n, 1), fn conn ->
      fun(conn, opts)
    end)
  end

  @doc """
  Sets up persistent stub for mock HTTP requests with validation.

  Configures Req.Test to stub all matching requests with path, method, headers, params, and body validation, returning stubbed response for unlimited calls.
  """
  @spec stub(atom(), keyword()) :: :ok
  def stub(module, opts \\ []) do
    Req.Test.stub(module, fn conn -> fun(conn, opts) end)
  end

  @doc """
  Validates mock HTTP request and returns stubbed response.

  Asserts request path, method, headers, query params, and body match expected values, then returns JSON response with specified status code.
  """
  @spec fun(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def fun(conn, opts) do
    {method, path} = opts[:path]

    assert conn.request_path == path
    assert String.to_atom(String.downcase(conn.method)) == method

    if opts[:headers] do
      for header <- opts[:headers] do
        assert header in conn.req_headers
      end
    end

    if opts[:params] do
      assert conn.query_params == payload(opts[:params])
    end

    if opts[:request] do
      assert conn.body_params == payload(opts[:request])
    end

    conn =
      conn
      |> Plug.Conn.put_status(Keyword.get(opts, :status, 200))
      |> Plug.Conn.put_resp_header("test", "value")

    conn =
      if opts[:resp_headers] do
        Enum.reduce(opts[:resp_headers], conn, fn {k, v}, conn ->
          if is_list(v) do
            Plug.Conn.put_resp_header(conn, k, hd(v))
          else
            Plug.Conn.put_resp_header(conn, k, v)
          end
        end)
      else
        conn
      end

    if opts[:response] do
      conn
      |> Req.Test.json(payload(opts[:response]))
    else
      conn
      |> Req.Test.text(opts[:body])
    end
  end

  @doc """
  Converts payload specification to actual data for mock responses.

  Returns empty string for nil, passes through maps unchanged, or loads and decodes JSON from file path for test fixtures.
  """
  @spec payload(nil | map() | String.t()) :: String.t() | map()
  def payload(nil), do: ""
  def payload(map) when is_map(map), do: map
  def payload(path), do: JSON.decode!(File.read!(Path.join("test/support/apis", path)))
end
