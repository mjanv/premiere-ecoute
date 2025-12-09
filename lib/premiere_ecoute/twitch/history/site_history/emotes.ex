defmodule PremiereEcoute.Twitch.History.SiteHistory.Emotes do
  @moduledoc """
  Extracts and analyzes emote usage from chat messages.

  Emotes are identified as space-separated words in chat messages.
  Common pattern: channel prefix followed by identifier (e.g., angledPepog, angledHello).

  AIDEV-NOTE: emote-extraction; parses message body to extract individual emotes
  """

  require Explorer.DataFrame, as: DataFrame
  alias Explorer.Series
  alias PremiereEcouteCore.Dataflow.Filters
  alias PremiereEcouteCore.Dataflow.Sink
  alias PremiereEcouteCore.Zipfile

  @doc "Reads and extracts emote data from chat messages in a zip file."
  @spec read(String.t()) :: Explorer.DataFrame.t()
  def read(file) do
    file
    |> Zipfile.csv(
      "request/site_history/chat_messages.csv",
      columns: ["time", "channel", "body"],
      dtypes: [{"time", {:naive_datetime, :microsecond}}]
    )
    |> extract_emotes()
    |> Sink.preprocess("time")
  end

  # AIDEV-NOTE: emote-pattern; assumes emotes are capitalized words or mixed-case identifiers
  # Common Twitch emote patterns: PascalCase, lowercase+PascalCase (e.g., angledPepog)
  defp extract_emotes(df) do
    # Convert to rows to extract emotes, then convert back to DataFrame
    df
    |> DataFrame.to_rows()
    |> Enum.flat_map(fn row ->
      body = row["body"]

      emotes =
        if is_binary(body) do
          body
          |> String.split(" ", trim: true)
          |> Enum.filter(&emote?/1)
        else
          []
        end

      # Create one row per emote, preserving the original message
      Enum.map(emotes, fn emote ->
        %{
          "time" => row["time"],
          "channel" => row["channel"],
          "emote" => emote,
          "body" => body
        }
      end)
    end)
    |> then(fn rows ->
      if Enum.empty?(rows) do
        # Return empty DataFrame with correct schema
        DataFrame.new(%{
          "time" => [],
          "channel" => [],
          "emote" => [],
          "body" => []
        })
      else
        DataFrame.new(rows)
      end
    end)
  end

  # Determines if a word is likely an emote
  # Heuristic: letters and numbers only, contains at least one uppercase letter, 3-25 characters
  defp emote?(word) do
    length = String.length(word)
    length >= 3 and length <= 25 and String.match?(word, ~r/^[a-zA-Z0-9]+$/) and String.match?(word, ~r/[A-Z]/)
  end

  @doc "Groups emotes by name with count."
  @spec group_by_emote(Explorer.DataFrame.t()) :: Explorer.DataFrame.t()
  def group_by_emote(df) do
    df
    |> Filters.group(
      [:emote],
      &[count: Series.count(&1["emote"]) |> Series.cast(:integer)],
      &[desc: &1["count"]]
    )
  end

  @doc "Filters emotes by prefix."
  @spec group_by_prefix(Explorer.DataFrame.t(), String.t()) :: Explorer.DataFrame.t()
  def group_by_prefix(df, prefix) do
    # AIDEV-NOTE: prefix-filter; cannot use Series.transform in filter_with, so we use to_rows
    df
    |> DataFrame.to_rows()
    |> Enum.filter(fn row ->
      emote = row["emote"]
      is_binary(emote) and String.starts_with?(emote, prefix)
    end)
    |> then(fn rows ->
      if Enum.empty?(rows) do
        # Return empty DataFrame with same schema
        DataFrame.new(%{
          "time" => [],
          "channel" => [],
          "emote" => [],
          "body" => [],
          "year" => [],
          "month" => [],
          "week" => [],
          "day" => [],
          "weekday" => [],
          "hour" => []
        })
      else
        DataFrame.new(rows)
      end
    end)
  end

  @doc "Filters emotes by specific emote name."
  @spec group_by_emote_name(Explorer.DataFrame.t(), String.t()) :: Explorer.DataFrame.t()
  def group_by_emote_name(df, emote_name) do
    df
    |> DataFrame.filter_with(fn data ->
      Series.equal(data["emote"], emote_name)
    end)
  end

  @doc "Groups emotes by time period."
  @spec group_by_period(Explorer.DataFrame.t(), String.t()) :: Explorer.DataFrame.t()
  def group_by_period(df, period) do
    groups = period_groups(period)

    df
    |> DataFrame.group_by(groups)
    |> DataFrame.summarise(count: Series.count(emote))
    |> apply_period_sort(period)
  end

  defp period_groups("day"), do: [:year, :month, :day]
  defp period_groups("week"), do: [:year, :week]
  defp period_groups("month"), do: [:year, :month]
  defp period_groups("year"), do: [:year]

  defp apply_period_sort(df, "day"),
    do: DataFrame.sort_by(df, asc: year, asc: month, asc: day)

  defp apply_period_sort(df, "week"), do: DataFrame.sort_by(df, asc: year, asc: week)
  defp apply_period_sort(df, "month"), do: DataFrame.sort_by(df, asc: year, asc: month)
  defp apply_period_sort(df, "year"), do: DataFrame.sort_by(df, asc: year)
end
