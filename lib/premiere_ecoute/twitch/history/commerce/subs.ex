defmodule PremiereEcoute.Twitch.History.Commerce.Subscriptions do
  @moduledoc false

  alias Explorer.{DataFrame, Series}
  alias PremiereEcouteCore.Dataflow.Filters
  alias PremiereEcouteCore.Dataflow.Sink
  alias PremiereEcouteCore.Dataflow.Statistics
  alias PremiereEcouteCore.Zipfile

  @doc "Reads subscription data from a zip file."
  @spec read(String.t()) :: Explorer.DataFrame.t()
  def read(file) do
    file
    |> Zipfile.csv(
      "request/commerce/subs/subscriptions.csv",
      columns: [
        "channel_login",
        "access_start",
        "access_end",
        "is_paid",
        "is_recurring",
        "is_token_sub",
        "is_prime_sub",
        "is_gift",
        "is_community_gift",
        "is_anonymous_gift",
        "is_auto_renewal",
        "is_cancelled_early",
        "is_prime_to_paid",
        "is_gift_to_paid",
        "is_tier_upgrade",
        "subscription_cancelled_at",
        "subscription_cancel_reason",
        "gift_quantity",
        "promotion_name"
      ],
      nil_values: [""],
      infer_schema_length: 10_000
    )
    |> DataFrame.mutate_with(
      &[
        is_paid: Series.equal(&1["is_paid"], "t"),
        is_recurring: Series.equal(&1["is_recurring"], "t"),
        is_token_sub: Series.equal(&1["is_token_sub"], "t"),
        is_prime_sub: Series.equal(&1["is_prime_sub"], "t"),
        is_gift: Series.equal(&1["is_gift"], "t"),
        is_community_gift: Series.equal(&1["is_community_gift"], "t"),
        is_anonymous_gift: Series.equal(&1["is_anonymous_gift"], "t"),
        is_auto_renewal: Series.equal(&1["is_auto_renewal"], "t"),
        is_cancelled_early: Series.equal(&1["is_cancelled_early"], "t"),
        is_prime_to_paid: Series.equal(&1["is_prime_to_paid"], "t"),
        is_gift_to_paid: Series.equal(&1["is_gift_to_paid"], "t"),
        is_tier_upgrade: Series.equal(&1["is_tier_upgrade"], "t"),
        access_start: Series.strptime(&1["access_start"], "%Y-%m-%d %H:%M:%S%.f")
      ]
    )
    |> Sink.preprocess("access_start")
  end

  @doc "Returns the number of subscription rows in the file."
  @spec n(String.t()) :: non_neg_integer()
  def n(file) do
    file
    |> read()
    |> Statistics.n_rows()
  end

  @doc "Groups subscriptions by month and year."
  @spec group_month_year(Explorer.DataFrame.t()) :: Explorer.DataFrame.t()
  def group_month_year(df) do
    df
    |> Filters.group(
      [:month, :year],
      &[
        subs: Series.n_distinct(&1["is_paid"])
      ],
      &[desc: &1["subs"]]
    )
  end
end
