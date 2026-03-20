defmodule PremiereEcoute.Playlists.Automations.Template do
  @moduledoc """
  Resolves date placeholders in automation name templates.

  Supported placeholders:

    - `%{year}`           — 4-digit year (e.g. "2026")
    - `%{month}`          — current month name (e.g. "March")
    - `%{next_month}`     — next month name
    - `%{previous_month}` — previous month name

  Unknown placeholders are left as-is.
  Resolution uses the date at call time, not scheduling time.
  """

  @month_names ~w(January February March April May June July August September October November December)

  @doc "Resolves all known placeholders in `template` against `date`."
  @spec resolve(String.t(), Date.t()) :: String.t()
  def resolve(template, date \\ Date.utc_today()) do
    next = Date.shift(date, month: 1)
    prev = Date.shift(date, month: -1)

    replacements = [
      {"%{year}", to_string(date.year)},
      {"%{month}", month_name(date)},
      {"%{next_month}", month_name(next)},
      {"%{previous_month}", month_name(prev)}
    ]

    Enum.reduce(replacements, template, fn {placeholder, value}, acc ->
      String.replace(acc, placeholder, value)
    end)
  end

  defp month_name(%Date{month: m}), do: Enum.at(@month_names, m - 1)
end
