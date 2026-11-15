defmodule PremiereEcoute.Wrapped.Cards.TopTrack do
  @moduledoc """
  Top track: the track with the viewer's best vote (see `PremiereEcoute.Wrapped.Card.top_tracks/2` for ties).
  """

  @behaviour PremiereEcoute.Wrapped.Card

  alias PremiereEcoute.Wrapped.Card

  @impl true
  def compute(listens) do
    case Card.top_tracks(listens, 1) do
      [track] ->
        %Card{
          type: :top_track,
          data: %{track: track},
          appearance: Card.appearance(track.cover_url),
          preview: Card.preview(track.artist, track.name)
        }

      [] ->
        :skip
    end
  end
end
