defmodule PremiereEcoute.Twitch.History.Commerce.BitsCheered do
  @moduledoc false

  require Explorer.DataFrame, as: DataFrame

  alias Explorer.Series
  alias PremiereEcouteCore.Dataflow.Sink
  alias PremiereEcouteCore.Zipfile

  @doc "Reads bits cheered data from a zip file."
  @spec read(String.t()) :: Explorer.DataFrame.t()
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
    |> DataFrame.sort_by(asc: time)
  end
end
