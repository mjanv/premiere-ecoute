defmodule PremiereEcoute.Twitch.History.Commerce.Subscriptions do
  @moduledoc false

  alias Explorer.{DataFrame, Series}
  alias PremiereEcouteCore.Dataflow.Filters
  alias PremiereEcouteCore.Dataflow.Sink
  alias PremiereEcouteCore.Dataflow.Statistics
  alias PremiereEcouteCore.Zipfile

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
      dtypes: [
        {"access_start", {:naive_datetime, :microsecond}},
        {"access_end", {:naive_datetime, :microsecond}},
        {"subscription_cancelled_at", {:naive_datetime, :millisecond}}
      ]
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
        is_tier_upgrade: Series.equal(&1["is_tier_upgrade"], "t")
      ]
    )
    |> Sink.preprocess("access_start")
  end

  def n(file) do
    file
    |> read()
    |> Statistics.n_rows()
  end

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
