defmodule PremiereEcouteWeb.Static.LegalTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias PremiereEcoute.Accounts.LegalDocument
  alias PremiereEcouteWeb.Static.Legal

  describe "document/1" do
    test "retrieves an existing legal document" do
      document = Legal.document(:terms)

      assert %LegalDocument{
               id: "terms",
               version: "1.1",
               date: "2026-04-08",
               title: "Conditions générales d'utilisation",
               body: _
             } = document
    end
  end
end
