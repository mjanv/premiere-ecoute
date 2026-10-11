defmodule PremiereEcouteMock do
  @moduledoc """
  Premiere Ecoute Mock service
  """

  use Boundary, deps: [PremiereEcoute], exports: []

  @doc """
  Returns the URL of the app's Twitch webhook endpoint.

  The port follows the current git worktree (see `PremiereEcoute.MixProject.worktree/0`), 4000 in the original checkout.
  """
  @spec webhook_url() :: String.t()
  def webhook_url do
    "http://localhost:#{Application.fetch_env!(:premiere_ecoute, :ports)[:web]}/webhooks/twitch"
  end
end
