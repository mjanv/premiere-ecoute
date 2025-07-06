defmodule PremiereEcoute.ApiMock do
  @moduledoc false

  import ExUnit.Assertions

  def expect(module, n \\ 1, opts \\ []) do
    Req.Test.expect(module, n, fn conn -> fun(conn, opts) end)
  end

  def stub(module, opts \\ []) do
    Req.Test.stub(module, fn conn -> fun(conn, opts) end)
  end

  def fun(conn, opts) do
    {method, path} = opts[:path]

    assert String.to_atom(String.downcase(conn.method)) == method
    assert conn.request_path == path

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
