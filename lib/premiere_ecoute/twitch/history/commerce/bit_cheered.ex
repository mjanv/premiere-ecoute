defmodule PremiereEcoute.Twitch.History.Commerce.BitsCheered do
  @moduledoc false

  alias Explorer.{DataFrame, Series}
  alias PremiereEcouteCore.Dataflow.Sink
  alias PremiereEcouteCore.Zipfile

  def read(file) do
    file
    |> Zipfile.csv(
      "request/commerce/bits/bits_cheered.csv",
      nil_values: [""],
      infer_schema_length: 10_000
    )
    |> DataFrame.mutate_with(
      &[
        time: Series.strptime(&1["time"], "%Y-%m-%d %H:%M:%S%.f")
      ]
    )
    |> Sink.preprocess("time")
  end
end
