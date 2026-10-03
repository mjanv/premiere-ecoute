defmodule PremiereEcoute.Youtube.VideoTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Youtube.Video

  describe "id_from_url/1" do
    test "reads the id of the usual YouTube links" do
      for url <- [
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtube.com/watch?feature=share&v=dQw4w9WgXcQ&t=42",
            "https://m.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://music.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtu.be/dQw4w9WgXcQ?t=3",
            "https://www.youtube.com/shorts/dQw4w9WgXcQ",
            "https://www.youtube.com/live/dQw4w9WgXcQ?si=abc",
            "https://www.youtube.com/embed/dQw4w9WgXcQ",
            "  https://www.youtube.com/watch?v=dQw4w9WgXcQ  "
          ] do
        assert Video.id_from_url(url) == {:ok, "dQw4w9WgXcQ"}, url
      end
    end

    test "rejects anything else" do
      for url <- [
            "",
            "not a url",
            "https://www.twitch.tv/videos/123",
            "https://www.youtube.com/@lanfeust",
            "https://www.youtube.com/watch?v=short",
            "https://www.youtube.com/playlist?list=PL1234567890A",
            "https://evil.com/watch?v=dQw4w9WgXcQ",
            "https://notyoutube.com/watch?v=dQw4w9WgXcQ"
          ] do
        assert Video.id_from_url(url) == :error, url
      end
    end
  end
end
