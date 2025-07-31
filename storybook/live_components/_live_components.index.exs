defmodule PremiereEcouteWeb.LiveComponents do
  use PhoenixStorybook.Index

  def folder_name, do: "Live Components"
  def folder_icon, do: {:fa, "wave-square"}
  def folder_open?, do: true

  def entry("spotify_player"), do: [name: "Spotify Player", icon: {:fa, "icon"}]
end
