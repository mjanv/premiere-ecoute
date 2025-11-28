defmodule PremiereEcoute.Festivals.Models.Static do
  @moduledoc """
  Static festival poster analyzer for testing.

  Returns hardcoded festival data streams for testing poster analysis without calling external AI APIs.
  """

  @behaviour PremiereEcoute.Festivals.Models.Model

  alias PremiereEcoute.Festivals.Festival

  @doc """
  Extracts hardcoded festival data for testing.

  Returns stream of partial and final festival data structures without calling external APIs. Input "1" returns simplified data, others return full festival data.
  """
  @spec extract_festival(String.t()) :: Enumerable.t()
  def extract_festival("1") do
    [
      {:partial, %Festival{}},
      {:partial, %Festival{name: "Awesome", concerts: []}},
      {:ok, %Festival{name: "Awesome", concerts: [%Festival.Concert{artist: "Sabrina Carpenter", date: ~D[2025-01-04]}]}}
    ]
    |> Stream.cycle()
    |> Stream.take(3)
  end

  def extract_festival(_) do
    [
      {:partial, %Festival{}},
      {:partial, %Festival{name: "Le Printemps de Bourges Crédit Mutuel", concerts: []}},
      {:partial, %Festival{name: "Le Printemps de Bourges Crédit Mutuel", location: "Bourges", country: "France", concerts: []}},
      {:partial,
       %Festival{
         name: "Le Printemps de Bourges Crédit Mutuel",
         location: "Bourges",
         country: "France",
         start_date: ~D[2024-04-23],
         end_date: ~D[2024-04-28],
         concerts: []
       }},
      {:ok,
       %Festival{
         name: "Le Printemps de Bourges Crédit Mutuel",
         location: "Bourges",
         country: "France",
         start_date: ~D[2024-04-23],
         end_date: ~D[2024-04-28],
         concerts: [
           %Festival.Concert{artist: "Mika", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Shaka Ponk", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "PLK", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Eddy de Pretto", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Worakls Orchestra", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Matt Pokora", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Luther", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Hoshi", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Trym", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Josman", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Bon Entendeur", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Martin Solveig", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Trinix", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Création « Messages Personnels »", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Françoise Hardy par Sage", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Cat Power sings Dylan '66", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Nuit Incolore", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Santa", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Fatoumata Diawara", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Kyo", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Eloi", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Olivia Ruiz", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Adèle Castillon", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Riopy", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Clara Ysé", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Timber Timbre", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Creeds Live", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Dimension Bonus", date: ~D[2024-04-23]},
           %Festival.Concert{artist: "Yamê", date: ~D[2024-04-23]}
         ]
       }}
    ]
    |> Stream.cycle()
    |> Stream.take(5)
  end
end
