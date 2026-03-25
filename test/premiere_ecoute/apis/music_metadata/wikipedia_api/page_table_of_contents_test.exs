defmodule PremiereEcoute.Apis.MusicMetadata.WikipediaApi.PageTableOfContentsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Page
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Section
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.TableOfContents

  setup {Req.Test, :verify_on_exit!}

  describe "table_of_contents/1" do
    test "returns structured TOC for an artist page" do
      ApiMock.expect(
        WikipediaApi,
        path: {:get, "/w/api.php"},
        headers: [{"user-agent", "PremiereEcoute/1.0 (maxime.janvier@gmail.com)"}],
        response: "wikipedia_api/page_table_of_contents/toc_artist/response.json",
        status: 200
      )

      {:ok, toc} = WikipediaApi.table_of_contents(%Page{id: 168_310, title: "Daft Punk"})

      assert %TableOfContents{
               title: "Daft Punk",
               page_id: 168_310,
               sections: sections
             } = toc

      assert length(sections) == 22

      assert [
               %Section{number: "1", title: "History", level: 1, anchor: "History"},
               %Section{number: "1.1", level: 2, anchor: "1987–1992:_Early_career_and_Darlin'"},
               %Section{number: "1.2", level: 2},
               %Section{number: "1.3", title: "1997–1999: Homework", level: 2}
               | _
             ] = sections
    end

    test "returns structured TOC for an album page" do
      ApiMock.expect(
        WikipediaApi,
        path: {:get, "/w/api.php"},
        headers: [{"user-agent", "PremiereEcoute/1.0 (maxime.janvier@gmail.com)"}],
        response: "wikipedia_api/page_table_of_contents/toc_album/response.json",
        status: 200
      )

      {:ok, toc} = WikipediaApi.table_of_contents(%Page{id: 38_898_753, title: "Random Access Memories"})

      assert %TableOfContents{
               title: "Random Access Memories",
               page_id: 38_898_753,
               sections: sections
             } = toc

      assert length(sections) == 28

      assert [
               %Section{number: "1", title: "Background", level: 1, anchor: "Background"}
               | _
             ] = sections

      assert %Section{number: "4.2", title: "The Collaborators", level: 2} =
               Enum.find(sections, &(&1.number == "4.2"))
    end

    test "HTML tags are stripped from section titles" do
      ApiMock.expect(
        WikipediaApi,
        path: {:get, "/w/api.php"},
        headers: [{"user-agent", "PremiereEcoute/1.0 (maxime.janvier@gmail.com)"}],
        response: "wikipedia_api/page_table_of_contents/toc_artist/response.json",
        status: 200
      )

      {:ok, %TableOfContents{sections: sections}} =
        WikipediaApi.table_of_contents(%Page{id: 168_310, title: "Daft Punk"})

      assert %Section{number: "1.5", title: "2004–2007: Human After All and Alive 2007"} =
               Enum.find(sections, &(&1.number == "1.5"))
    end
  end
end
