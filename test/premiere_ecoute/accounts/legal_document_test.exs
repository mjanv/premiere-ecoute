defmodule PremiereEcoute.Accounts.LegalDocumentTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.LegalDocument

  describe "Legal document" do
    test "can be built" do
      attrs = %{version: "1.0", date: ~D[2000-01-01], language: "fr", title: "Title"}
      document = LegalDocument.build("priv/legal/terms.md", attrs, "body")

      assert document == %LegalDocument{
               id: "terms",
               version: "1.0",
               date: ~D[2000-01-01],
               title: "Title",
               body: "body",
               language: "fr"
             }
    end
  end
end
