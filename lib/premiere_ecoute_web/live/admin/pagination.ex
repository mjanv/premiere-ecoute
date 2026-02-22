defmodule PremiereEcouteWeb.Admin.Pagination do
  @moduledoc """
  Shared pagination helpers for admin LiveViews.
  """

  @doc """
  Returns a list of page numbers and `:ellipsis` atoms for a pagination control.

  Limits the range to at most 7 entries, collapsing distant pages into ellipsis markers.
  """
  @spec pagination_range(integer(), integer()) :: list(integer() | :ellipsis)
  def pagination_range(current_page, total_pages) do
    cond do
      total_pages <= 7 ->
        1..total_pages |> Enum.to_list()

      current_page <= 4 ->
        [1, 2, 3, 4, 5, :ellipsis, total_pages]

      current_page >= total_pages - 3 ->
        [1, :ellipsis, total_pages - 4, total_pages - 3, total_pages - 2, total_pages - 1, total_pages]

      true ->
        [1, :ellipsis, current_page - 1, current_page, current_page + 1, :ellipsis, total_pages]
    end
  end
end
