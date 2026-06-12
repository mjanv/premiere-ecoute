defmodule PremiereEcoute.Telemetry.PodcastMetricsTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Telemetry.PodcastMetrics

  defp attach(event) do
    test = self()
    ref = make_ref()

    :telemetry.attach(
      {__MODULE__, ref},
      event,
      fn name, measurements, metadata, _ -> send(test, {:telemetry, name, measurements, metadata}) end,
      nil
    )

    on_exit(fn -> :telemetry.detach({__MODULE__, ref}) end)
  end

  test "ingestion/2 emits duration and result" do
    attach([:premiere_ecoute, :podcasts, :ingestion])

    PodcastMetrics.ingestion(:ok, 42)

    assert_receive {:telemetry, [:premiere_ecoute, :podcasts, :ingestion], %{duration: 42}, %{result: :ok}}
  end

  test "feed/1 emits the response status" do
    attach([:premiere_ecoute, :podcasts, :feed])

    PodcastMetrics.feed(404)

    assert_receive {:telemetry, [:premiere_ecoute, :podcasts, :feed], _measurements, %{status: 404}}
  end

  test "audio/1 emits the source" do
    attach([:premiere_ecoute, :podcasts, :audio])

    PodcastMetrics.audio(:web)

    assert_receive {:telemetry, [:premiere_ecoute, :podcasts, :audio], _measurements, %{source: :web}}
  end
end
