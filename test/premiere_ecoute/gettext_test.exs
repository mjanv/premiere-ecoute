defmodule PremiereEcoute.GettextTest do
  use ExUnit.Case, async: true

  describe "gettext/1" do
    test "returns original message when no translation exists" do
      Gettext.put_locale(PremiereEcoute.Gettext, "en")
      assert PremiereEcoute.Gettext.gettext("Non-existent message") == "Non-existent message"
    end

    test "translates to French" do
      Gettext.put_locale(PremiereEcoute.Gettext, "fr")
      result = PremiereEcoute.Gettext.gettext("Upload festival posters and create playlists for your events")
      assert result == "Téléchargez des affiches de festivals et créez des playlists pour vos événements"
    end
  end

  describe "locale/0" do
    test "returns current locale" do
      Gettext.put_locale(PremiereEcoute.Gettext, "fr")
      assert PremiereEcoute.Gettext.locale() == "fr"
    end

    test "reflects locale changes" do
      Gettext.put_locale(PremiereEcoute.Gettext, "it")
      assert PremiereEcoute.Gettext.locale() == "it"
    end
  end
end
