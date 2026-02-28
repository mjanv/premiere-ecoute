defmodule PremiereEcouteWeb.Static.LegalTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias PremiereEcoute.Accounts.LegalDocument
  alias PremiereEcouteWeb.Static.Legal

  describe "document/1" do
    test "retrieves an existing legal document" do
      document = Legal.document(:terms)

      assert %LegalDocument{
               id: "terms",
               version: "1.0",
               date: "2025-07-21",
               title: "Conditions générales d'utilisation",
               body: _
             } = document
    end
  end
end
