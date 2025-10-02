defmodule PremiereEcoute.Festivals.Services.PosterAnalyzerTest do
  use PremiereEcoute.DataCase

  import PremiereEcoute.AccountsFixtures

  alias PremiereEcoute.Festivals.Festival
  alias PremiereEcoute.Festivals.Services.PosterAnalyzer

  describe "analyze_poster/2" do
    test "can analyze a festival poster and return the final result" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      image_path = Path.join([File.cwd!(), "test", "support", "festivals", "printemps_2024.png"])

      {:ok, festival} = PosterAnalyzer.analyze_poster(scope, image_path)

      assert %Festival{
               name: "Le Printemps de Bourges Crédit Mutuel",
               location: "Bourges",
               country: "France",
               start_date: ~D[2024-04-23],
               end_date: ~D[2024-04-28],
               concerts: concerts
             } = festival

      assert length(concerts) == 29
      assert Enum.any?(concerts, fn concert -> concert.artist == "Mika" end)
      assert Enum.any?(concerts, fn concert -> concert.artist == "Shaka Ponk" end)
      assert Enum.any?(concerts, fn concert -> concert.artist == "PLK" end)
    end
  end
end
