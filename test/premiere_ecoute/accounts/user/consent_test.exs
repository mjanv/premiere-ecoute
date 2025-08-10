defmodule PremiereEcoute.Accounts.User.ConsentTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts.LegalDocument
  alias PremiereEcoute.Accounts.User.Consent
  alias PremiereEcoute.Events.ConsentGiven
  alias PremiereEcoute.Events.Store

  setup do
    user = user_fixture()

    privacy = %LegalDocument{id: "privacy", version: "1.0", language: "fr", date: ~D[2000-01-01], title: "Privacy", body: ""}
    cookies = %LegalDocument{id: "cookies", version: "1.0", language: "fr", date: ~D[2000-01-01], title: "Cookies", body: ""}
    terms = %LegalDocument{id: "terms", version: "1.0", language: "fr", date: ~D[2000-01-01], title: "Terms", body: ""}

    documents = %{privacy: privacy, cookies: cookies, terms: terms}

    {:ok, user: user, document: privacy, documents: documents}
  end

  describe "accept/2" do
    test "can create one accepted consent", %{user: user, document: document} do
      {:ok, consent} = Consent.accept(user, document)

      assert %Consent{document: :privacy, version: "1.0", accepted: true, user_id: user_id} = consent
      assert user_id == user.id

      assert Store.last("user-#{user.id}") == %ConsentGiven{id: user.id, document: "privacy", version: "1.0", accepted: true}
    end

    test "can create multiple accepted consents", %{user: user, documents: documents} do
      {:ok, _multi} = Consent.accept(user, documents)

      assert [
               %Consent{document: :cookies, version: "1.0", accepted: true, user_id: user_id},
               %Consent{document: :terms, version: "1.0", accepted: true, user_id: user_id},
               %Consent{document: :privacy, version: "1.0", accepted: true, user_id: user_id}
             ] = Consent.all(user_id: user.id)

      assert Store.last("user-#{user.id}", 3) == [
               %ConsentGiven{id: user.id, document: "cookies", version: "1.0", accepted: true},
               %ConsentGiven{id: user.id, document: "terms", version: "1.0", accepted: true},
               %ConsentGiven{id: user.id, document: "privacy", version: "1.0", accepted: true}
             ]
    end

    test "can update one refused consent", %{user: user, document: document} do
      {:ok, consent1} = Consent.refuse(user, document)
      {:ok, consent2} = Consent.accept(user, document)

      consent = Consent.get(consent1.id)

      assert consent1.id == consent2.id
      assert %Consent{document: :privacy, version: "1.0", accepted: true, user_id: user_id} = consent
      assert user_id == user.id

      assert Store.last("user-#{user.id}") == %ConsentGiven{id: user.id, document: "privacy", version: "1.0", accepted: true}
    end
  end

  describe "refuse/2" do
    setup do
      user = user_fixture()
      document = %LegalDocument{id: "privacy", version: "1.0", language: "fr", date: ~D[2000-01-01], title: "Privacy", body: ""}

      {:ok, %{user: user, document: document}}
    end

    test "can create one refused consent", %{user: user, document: document} do
      {:ok, consent} = Consent.refuse(user, document)

      assert %Consent{document: :privacy, version: "1.0", accepted: false, user_id: user_id} = consent
      assert user_id == user.id

      assert Store.last("user-#{user.id}") == %ConsentGiven{id: user.id, document: "privacy", version: "1.0", accepted: false}
    end

    test "can update one accepted consent", %{user: user, document: document} do
      {:ok, consent1} = Consent.accept(user, document)
      {:ok, consent2} = Consent.refuse(user, document)

      consent = Consent.get(consent1.id)

      assert consent1.id == consent2.id
      assert %Consent{document: :privacy, version: "1.0", accepted: false, user_id: user_id} = consent
      assert user_id == user.id

      assert Store.last("user-#{user.id}") == %ConsentGiven{id: user.id, document: "privacy", version: "1.0", accepted: false}
    end
  end

  describe "approval/2" do
    test "is granted all legal documents are accepted", %{user: user, documents: documents} do
      {:ok, _} = Consent.accept(user, documents.privacy)
      {:ok, _} = Consent.accept(user, documents.cookies)
      {:ok, _} = Consent.accept(user, documents.terms)

      assert Consent.approval(user, documents) == true
    end

    test "is refused when not all legal documents are accepted", %{user: user, documents: documents} do
      {:ok, _} = Consent.accept(user, documents.privacy)
      {:ok, _} = Consent.accept(user, documents.cookies)
      {:ok, _} = Consent.refuse(user, documents.terms)

      assert Consent.approval(user, documents) == false
    end

    test "is refused when a consent  is missing", %{user: user, documents: documents} do
      {:ok, _} = Consent.accept(user, documents.privacy)
      {:ok, _} = Consent.accept(user, documents.cookies)

      assert Consent.approval(user, documents) == false
    end

    test "is refused when not all legal documents are at the right version", %{user: user, documents: documents} do
      {:ok, _} = Consent.accept(user, documents.privacy)
      {:ok, _} = Consent.accept(user, %{documents.cookies | version: "0.8"})
      {:ok, _} = Consent.accept(user, documents.terms)

      assert Consent.approval(user, documents) == false
    end

    test "is updated when the last consent is applied", %{user: user, documents: documents} do
      {:ok, _} = Consent.accept(user, documents.privacy)
      {:ok, _} = Consent.accept(user, documents.cookies)
      approval1 = Consent.approval(user, documents)
      {:ok, _} = Consent.accept(user, documents.terms)
      approval2 = Consent.approval(user, documents)

      assert {approval1, approval2} == {false, true}
    end
  end
end
