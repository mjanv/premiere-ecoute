defmodule PremiereEcoute.Wrapped.Cards.YouAndChat do
  @moduledoc """
  You and the chat: the album where the viewer's score is the furthest from the session score, and the one where it is the closest.
  """

  @behaviour PremiereEcoute.Wrapped.Card

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Listen

  @impl true
  def compute(listens) do
    case listens |> Listen.albums() |> Enum.filter(&(&1.result.score && &1.result.chat_score)) |> Enum.sort_by(&gap/1) do
      [closest, _ | _] = compared ->
        furthest = List.last(compared)

        %Card{
          type: :you_and_chat,
          data: %{furthest: entry(furthest), closest: entry(closest)},
          appearance: Card.appearance(furthest),
          preview: Card.preview(furthest)
        }

      _ ->
        :skip
    end
  end

  defp gap(listen), do: abs(listen.result.score - listen.result.chat_score)

  defp entry(listen), do: listen |> Card.album() |> Map.merge(%{you: listen.result.score, chat: listen.result.chat_score})
end
