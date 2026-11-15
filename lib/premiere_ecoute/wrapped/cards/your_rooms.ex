defmodule PremiereEcoute.Wrapped.Cards.YourRooms do
  @moduledoc """
  Your rooms: the streamers the viewer listened with, by number of sessions. Skipped with a single streamer.
  """

  @behaviour PremiereEcoute.Wrapped.Card

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Listen

  @max_rooms 4

  @impl true
  def compute(listens) do
    albums = Listen.albums(listens)

    case albums
         |> Enum.flat_map(& &1.result.streamers)
         |> Enum.frequencies()
         |> Enum.sort_by(fn {name, count} -> {-count, name} end) do
      [_, _ | _] = rooms ->
        latest = List.last(albums)

        %Card{
          type: :your_rooms,
          data: %{rooms: rooms |> Enum.take(@max_rooms) |> Enum.map(fn {name, count} -> %{name: name, sessions: count} end)},
          appearance: Card.appearance(latest),
          preview: Card.preview(latest)
        }

      _ ->
        :skip
    end
  end
end
