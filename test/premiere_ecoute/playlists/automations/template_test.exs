defmodule PremiereEcoute.Playlists.Automations.TemplateTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Playlists.Automations.Template

  @months ~w(January February March April May June July August September October November December)

  describe "resolve/2" do
    test "resolves %{year}" do
      assert Template.resolve("Best of %{year}", ~D[2026-03-15]) == "Best of 2026"
    end

    test "resolves %{month}" do
      assert Template.resolve("Discoveries %{month}", ~D[2026-03-15]) == "Discoveries March"
    end

    test "resolves %{next_month}" do
      assert Template.resolve("Preview %{next_month}", ~D[2026-03-15]) == "Preview April"
    end

    test "resolves %{previous_month}" do
      assert Template.resolve("Best of %{previous_month}", ~D[2026-03-15]) == "Best of February"
    end

    test "resolves multiple placeholders in one template" do
      assert Template.resolve("%{month} %{year}", ~D[2026-06-01]) == "June 2026"
    end

    test "resolves %{next_month} wraps at December → January" do
      assert Template.resolve("%{next_month}", ~D[2026-12-01]) == "January"
    end

    test "resolves %{previous_month} wraps at January → December" do
      assert Template.resolve("%{previous_month}", ~D[2026-01-01]) == "December"
    end

    test "%{next_month} %{year} in December gives January with same year" do
      assert Template.resolve("%{next_month} %{year}", ~D[2026-12-01]) == "January 2026"
    end

    test "%{previous_month} %{year} in January gives December with same year" do
      assert Template.resolve("%{previous_month} %{year}", ~D[2026-01-01]) == "December 2026"
    end

    test "leaves unknown placeholders as-is" do
      assert Template.resolve("Hello %{unknown}", ~D[2026-03-15]) == "Hello %{unknown}"
    end

    test "returns template unchanged when no placeholders" do
      assert Template.resolve("My Playlist", ~D[2026-03-15]) == "My Playlist"
    end

    test "all months resolve correctly" do
      for {month_name, month_number} <- Enum.with_index(@months, 1) do
        date = Date.new!(2026, month_number, 1)
        assert Template.resolve("%{month}", date) == month_name
      end
    end

    test "defaults to today when no date given" do
      year = to_string(Date.utc_today().year)
      assert Template.resolve("%{year}") == year
    end
  end
end
