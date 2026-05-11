defmodule PremiereEcoute.Twitch.RewardCatalog do
  @moduledoc """
  Developer-defined catalog of reusable Twitch channel point reward templates.

  Streamer can add any of these to a collection session instead of creating a reward from scratch.
  """

  @type entry :: %{
          id: String.t(),
          title: String.t(),
          labels: %{String.t() => String.t()},
          cost: pos_integer(),
          prompt: String.t(),
          prompts: %{String.t() => String.t()},
          is_user_input_required: boolean()
        }

  @catalog [
    %{
      id: "song_request",
      title: "Song request",
      labels: %{"en" => "Song request", "fr" => "Demande de chanson", "it" => "Richiesta canzone"},
      cost: 1_000,
      prompt: "Request a song to be added to the listening session",
      prompts: %{
        "en" => "Request a song to be added to the listening session",
        "fr" => "Demandez une chanson à ajouter à la session d'écoute",
        "it" => "Richiedi una canzone da aggiungere alla sessione di ascolto"
      },
      is_user_input_required: true
    },
    %{
      id: "skip_track",
      title: "Skip current track",
      labels: %{"en" => "Skip current track", "fr" => "Passer le morceau actuel", "it" => "Salta traccia attuale"},
      cost: 5_000,
      prompt: "Vote to skip the current track being evaluated",
      prompts: %{
        "en" => "Vote to skip the current track being evaluated",
        "fr" => "Votez pour passer le morceau en cours d'évaluation",
        "it" => "Vota per saltare la traccia attualmente in valutazione"
      },
      is_user_input_required: false
    }
  ]

  @doc "Returns all catalog entries."
  @spec list() :: [entry()]
  def list, do: @catalog

  @doc "Finds a catalog entry by id."
  @spec get(String.t()) :: entry() | nil
  def get(id), do: Enum.find(@catalog, &(&1.id == id))
end
