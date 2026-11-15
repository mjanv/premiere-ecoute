defmodule PremiereEcoute.Wrapped.Cards.FirstVote do
  @moduledoc """
  First vote: the first album of the year and the day of its first vote.
  """

  @behaviour PremiereEcoute.Wrapped.Card

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Listen

  @impl true
  def compute(listens) do
    case Listen.albums(listens) do
      [first | _] -> card(first)
      [] -> :skip
    end
  end

  defp card(first) do
    %Card{
      type: :first_vote,
      data: %{album: Card.album(first), date: first.result.voted_at |> DateTime.to_date() |> Date.to_iso8601()},
      appearance: Card.appearance(first),
      preview: Card.preview(first)
    }
  end
end
