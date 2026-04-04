defmodule PremiereEcoute.Wantlists do
  @moduledoc """
  Context for managing user wantlists.

  Each user has a single default wantlist. Items reference discography records
  (albums, singles, or artists) by FK. The wantlist is created on first use.
  """

  # TODO: Refactor overall Wantlists context

  alias PremiereEcoute.Wantlists.Services.AddTrack
  alias PremiereEcoute.Wantlists.Wantlist
  alias PremiereEcoute.Wantlists.WantlistItem

  defdelegate get_wantlist(user_id), to: Wantlist, as: :get_by_user
  defdelegate add_item(user_id, type, record_id), to: WantlistItem, as: :add
  defdelegate in_wantlist?(user_id, type, record_id), to: WantlistItem, as: :exists?
  defdelegate remove_item(user_id, item_id), to: WantlistItem, as: :remove
  defdelegate remove_item(user_id, type, record_id), to: WantlistItem, as: :remove
  defdelegate wantlisted_spotify_ids(user_id, spotify_ids), to: WantlistItem
  defdelegate add_radio_track(user_id, spotify_id), to: AddTrack
end
