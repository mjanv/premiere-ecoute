defmodule PremiereEcoute.Wrapped do
  @moduledoc """
  Viewer Wrapped: a yearly recap of the albums and singles a viewer voted on.

  Read-only over Sessions and Discography. A recap is computed once in the background, stored as a frozen JSON snapshot (`PremiereEcoute.Wrapped.Recap`) and only rendered by the page.
  """

  use PremiereEcouteCore.Context

  alias PremiereEcoute.Wrapped.Recap
  alias PremiereEcoute.Wrapped.Services.BuildCards
  alias PremiereEcoute.Wrapped.Services.ComputeRecap
  alias PremiereEcoute.Wrapped.Services.ResolvePreviews
  alias PremiereEcoute.Wrapped.Services.TrackUsage

  defdelegate year?(year), to: Recap
  defdelegate version(), to: Recap
  defdelegate get_recap(user, year), to: Recap, as: :current
  defdelegate promoted?(recap), to: Recap
  defdelegate available_recap(user), to: Recap, as: :available
  defdelegate get_shared_recap(year, token), to: Recap, as: :shared
  defdelegate fetch_recap(id), to: Recap, as: :get
  defdelegate delete_recap(recap), to: Recap, as: :delete

  defdelegate topic(user), to: ComputeRecap
  defdelegate compute(user, year), to: ComputeRecap
  defdelegate request_recap(user, year), to: ComputeRecap, as: :request
  defdelegate schedule(year), to: ComputeRecap
  defdelegate schedule_missing(year), to: ComputeRecap
  defdelegate ensure_recap(user), to: ComputeRecap, as: :ensure
  defdelegate pending(), to: ComputeRecap

  defdelegate list_recaps(year, search, page, page_size), to: Recap, as: :list_for_admin
  defdelegate recap_stats(year), to: Recap, as: :stats
  defdelegate eligible_ids(year), to: PremiereEcoute.Sessions, as: :list_voter_ids

  defdelegate cards(listens), to: BuildCards
  defdelegate demo_cards(), to: BuildCards

  defdelegate previews(cards), to: ResolvePreviews

  defdelegate viewed(recap, render \\ nil), to: TrackUsage
  defdelegate shared(recap, render \\ nil), to: TrackUsage
end
