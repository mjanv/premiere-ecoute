defmodule PremiereEcoute.TelemetryTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Telemetry.ApiMetrics
  alias PremiereEcoute.Telemetry.ReqPipeline

  setup do
    self = self()
    id = UUID.uuid4()

    :telemetry.attach_many(
      id,
      [[:premiere_ecoute, :apis, :api_call], [:premiere_ecoute, :apis, :webhook_event]],
      fn name, measurements, metadata, _ -> send(self, {:telemetry_event, name, measurements, metadata}) end,
      nil
    )

    on_exit(fn -> :telemetry.detach(id) end)

    {:ok, bypass: Bypass.open()}
  end

  describe "api_call/2" do
    test "can send provider API call events to telemetry from Req request and responses", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn -> Plug.Conn.resp(conn, 200, "pong") end)

      request = Req.new(url: "http://localhost:#{bypass.port}/ping")
      response = Req.get!(request)

      ApiMetrics.api_call(:twitch, {request, response})

      assert_receive {:telemetry_event, [:premiere_ecoute, :apis, :api_call], %{},
                      %{provider: :twitch, method: :get, url: "/ping", status: 200}}
    end

    test "can send provider API call events to telemetry from Req pipeline", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn -> Plug.Conn.resp(conn, 200, "ping") end)

      {:ok, _} =
        [url: "http://localhost:#{bypass.port}/pong"]
        |> Req.new()
        |> ReqPipeline.attach(:twitch, &ApiMetrics.api_call/2)
        |> Req.get()

      assert_receive {:telemetry_event, [:premiere_ecoute, :apis, :api_call], %{},
                      %{provider: :twitch, method: :get, url: "/pong", status: 200}}
    end
  end

  describe "webhook_event/2" do
    test "can send provider webhook events to telemetry" do
      ApiMetrics.webhook_event(:twitch, "notification")

      assert_receive {:telemetry_event, [:premiere_ecoute, :apis, :webhook_event], %{},
                      %{provider: :twitch, type: "notification"}}
    end
  end
end
