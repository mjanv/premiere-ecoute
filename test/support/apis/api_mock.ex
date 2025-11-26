defmodule PremiereEcoute.ApiMock do
  @moduledoc """
  API mocking utilities for tests.

  Provides helpers to mock HTTP API responses using Req.Test, with support for request validation and response stubbing.
  """

  import ExUnit.Assertions

  def expect(module, opts \\ []) do
    Req.Test.expect(module, Keyword.get(opts, :n, 1), fn conn ->
      fun(conn, opts)
    end)
  end

  def stub(module, opts \\ []) do
    Req.Test.stub(module, fn conn -> fun(conn, opts) end)
  end

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

    conn
    |> Plug.Conn.put_status(Keyword.get(opts, :status, 200))
    |> Req.Test.json(payload(opts[:response]))
  end

  def payload(nil), do: ""
  def payload(map) when is_map(map), do: map
  def payload(path), do: JSON.decode!(File.read!(Path.join("test/support/apis", path)))
end
