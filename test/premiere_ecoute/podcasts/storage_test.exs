defmodule PremiereEcoute.Podcasts.StorageTest do
  use ExUnit.Case, async: false

  alias PremiereEcoute.Podcasts.Storage

  describe "audio_key/2 and cover_key/2" do
    test "audio key is stable and namespaced by show" do
      assert Storage.audio_key(42, "abc-guid") == "podcasts/42/episodes/abc-guid.mp3"
    end

    test "cover key normalizes the extension" do
      assert Storage.cover_key(7, ".JPG") == "podcasts/7/cover.jpg"
      assert Storage.cover_key(7, "png") == "podcasts/7/cover.png"
    end
  end

  describe "public_url/1" do
    setup do
      original = Application.get_env(:premiere_ecoute, Storage)
      Application.put_env(:premiere_ecoute, Storage, public_base_url: "https://cdn.example.com/")
      on_exit(fn -> restore(original) end)
    end

    test "joins the configured base with the key, avoiding double slashes" do
      assert Storage.public_url("podcasts/1/episodes/x.mp3") == "https://cdn.example.com/podcasts/1/episodes/x.mp3"
    end

    test "tolerates a leading slash on the key" do
      assert Storage.public_url("/podcasts/1/cover.jpg") == "https://cdn.example.com/podcasts/1/cover.jpg"
    end

    defp restore(nil), do: Application.delete_env(:premiere_ecoute, Storage)
    defp restore(value), do: Application.put_env(:premiere_ecoute, Storage, value)
  end
end
