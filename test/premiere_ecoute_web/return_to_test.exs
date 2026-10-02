defmodule PremiereEcouteWeb.ReturnToTest do
  use ExUnit.Case, async: true

  alias PremiereEcouteWeb.ReturnTo

  describe "resolve/2" do
    test "accepts the history page with its filters" do
      path = "/sessions/retrospective?month=9&period=month&source=album&year=2026"
      assert ReturnTo.resolve(path, "/sessions/retrospective") == {path, :history}
    end

    test "accepts viewer history pages" do
      assert {"/sessions/retrospective/votes?page=2", :history} =
               ReturnTo.resolve("/sessions/retrospective/votes?page=2", "/x")
    end

    test "accepts discography, home and profile pages" do
      assert {"/discography/albums/abc", :album} = ReturnTo.resolve("/discography/albums/abc", "/x")
      assert {"/discography/artists/abc", :artist} = ReturnTo.resolve("/discography/artists/abc", "/x")
      assert {"/discography/singles/abc", :single} = ReturnTo.resolve("/discography/singles/abc", "/x")
      assert {"/home", :home} = ReturnTo.resolve("/home", "/x")
      assert {"/users/someone", :profile} = ReturnTo.resolve("/users/someone", "/x")
    end

    test "falls back to the default when missing" do
      assert ReturnTo.resolve(nil, "/sessions/retrospective") == {"/sessions/retrospective", :history}
      assert ReturnTo.resolve("", "/sessions/retrospective") == {"/sessions/retrospective", :history}
    end

    test "rejects external and malformed targets" do
      for bad <- [
            "//evil.com",
            "https://evil.com",
            "javascript:alert(1)",
            "/\\evil.com",
            "/sessions/retrospective\r\nX: y",
            "/admin/oban",
            "/sessionsretrospective",
            "/home/../admin",
            "/users/settings",
            %{"a" => "b"}
          ] do
        assert ReturnTo.resolve(bad, "/sessions/retrospective") == {"/sessions/retrospective", :history},
               "expected #{inspect(bad)} to be rejected"
      end
    end
  end

  describe "session_href/3" do
    test "appends the encoded return_to" do
      href = ReturnTo.session_href("streamer", "token123", "/sessions/retrospective?source=album&year=2026")

      assert href ==
               "/sessions/streamer/token123?return_to=%2Fsessions%2Fretrospective%3Fsource%3Dalbum%26year%3D2026"
    end

    test "leaves the link plain without a valid return_to" do
      assert ReturnTo.session_href("streamer", "token123", nil) == "/sessions/streamer/token123"
      assert ReturnTo.session_href("streamer", "token123", "//evil.com") == "/sessions/streamer/token123"
    end
  end

  describe "current_path/1" do
    test "keeps path and query only" do
      assert ReturnTo.current_path("http://localhost:4000/sessions/retrospective?a=1#frag") ==
               "/sessions/retrospective?a=1"

      assert ReturnTo.current_path("http://localhost:4000/home") == "/home"
    end
  end
end
