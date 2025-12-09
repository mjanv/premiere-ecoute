defmodule PremiereEcoute.Twitch.History.Community.Unfollows do
  @moduledoc false

  require Explorer.DataFrame, as: DataFrame

  alias PremiereEcouteCore.Zipfile

  @doc "Reads unfollow data from a zip file."
  @spec read(String.t()) :: Explorer.DataFrame.t()
  def read(file) do
    Zipfile.csv(
      file,
      "request/community/follows/unfollow.csv",
      columns: ["time", "channel"],
      dtypes: [{"time", {:naive_datetime, :microsecond}}]
    )
  end

  @doc "Returns all unfollows filtered to exclude nil channels."
  @spec all(String.t()) :: Explorer.DataFrame.t()
  def all(file) do
    file
    |> read()
    |> DataFrame.filter(not is_nil(channel))
  end

  @doc "Returns the count of unfollows excluding nil channels."
  @spec count(String.t()) :: non_neg_integer()
  def count(file) do
    file
    |> read()
    |> DataFrame.filter(not is_nil(channel))
    |> DataFrame.shape()
    |> elem(0)
  end
end
