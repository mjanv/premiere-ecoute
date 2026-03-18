defmodule PremiereEcouteWeb.Mcp.Components.GreeterTest do
  use ExUnit.Case

  alias Hermes.Server.Frame
  alias PremiereEcouteWeb.Mcp.Components.Greeter

  test "greeter tool greets someone warmly" do
    frame = %Frame{}

    assert {:reply, resp, ^frame} = Greeter.execute(%{name: "Alice"}, frame)
    assert %Hermes.Server.Response{type: :tool, content: content} = resp
    assert [%{"text" => "Hello Alice! Welcome to the MCP world!", "type" => "text"}] = content
  end

  test "greeter tool works with different names" do
    frame = %Frame{}

    assert {:reply, resp, ^frame} = Greeter.execute(%{name: "Bob"}, frame)
    assert %Hermes.Server.Response{type: :tool, content: content} = resp
    assert [%{"text" => "Hello Bob! Welcome to the MCP world!", "type" => "text"}] = content
  end
end
