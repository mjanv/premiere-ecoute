defmodule PremiereEcouteWeb.Storybook.LiveComponents.SpotifyPlayer do
  @moduledoc false

  use PhoenixStorybook.Story, :live_component

  def component, do: PremiereEcouteWeb.Sessions.Components.SpotifyPlayer

  def attributes, do: []
  def slots, do: []
  def variations, do: []
end
