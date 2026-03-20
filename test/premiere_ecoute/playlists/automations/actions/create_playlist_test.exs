defmodule PremiereEcoute.Playlists.Automations.Actions.CreatePlaylistTest do
  use PremiereEcoute.DataCase, async: true

  import Hammox

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.Automations.Actions.CreatePlaylist

  setup :verify_on_exit!

  defp scope, do: user_scope_fixture(user_fixture())

  defp created_playlist(name),
    do: %LibraryPlaylist{provider: :spotify, playlist_id: "new_pl_id", title: name}

  describe "validate_config/1" do
    test "valid with name" do
      assert :ok = CreatePlaylist.validate_config(%{"name" => "My Playlist"})
    end

    test "invalid when name is missing" do
      assert {:error, _} = CreatePlaylist.validate_config(%{})
    end

    test "invalid when name is empty string" do
      assert {:error, _} = CreatePlaylist.validate_config(%{"name" => ""})
    end
  end

  describe "execute/3 — placeholder resolution" do
    test "resolves %{year}" do
      year = to_string(Date.utc_today().year)

      expect(SpotifyApi, :create_playlist, fn _scope, %LibraryPlaylist{title: title} ->
        assert title == "Best of #{year}"
        {:ok, created_playlist(title)}
      end)

      assert {:ok, %{"playlist_name" => "Best of " <> ^year}} =
               CreatePlaylist.execute(%{"name" => "Best of %{year}"}, %{}, scope())
    end

    test "resolves %{month} to current month name" do
      month_names = ~w(January February March April May June July August September October November December)
      month = Enum.at(month_names, Date.utc_today().month - 1)

      expect(SpotifyApi, :create_playlist, fn _scope, %LibraryPlaylist{title: title} ->
        {:ok, created_playlist(title)}
      end)

      assert {:ok, %{"playlist_name" => name}} =
               CreatePlaylist.execute(%{"name" => "Discoveries %{month}"}, %{}, scope())

      assert name == "Discoveries #{month}"
    end

    test "resolves %{next_month}" do
      month_names = ~w(January February March April May June July August September October November December)
      next_idx = rem(Date.utc_today().month, 12)
      next_month = Enum.at(month_names, next_idx)

      expect(SpotifyApi, :create_playlist, fn _scope, %LibraryPlaylist{title: title} ->
        {:ok, created_playlist(title)}
      end)

      assert {:ok, %{"playlist_name" => name}} =
               CreatePlaylist.execute(%{"name" => "Preview %{next_month}"}, %{}, scope())

      assert name == "Preview #{next_month}"
    end

    test "resolves %{previous_month}" do
      month_names = ~w(January February March April May June July August September October November December)
      prev_idx = rem(Date.utc_today().month - 2 + 12, 12)
      prev_month = Enum.at(month_names, prev_idx)

      expect(SpotifyApi, :create_playlist, fn _scope, %LibraryPlaylist{title: title} ->
        {:ok, created_playlist(title)}
      end)

      assert {:ok, %{"playlist_name" => name}} =
               CreatePlaylist.execute(%{"name" => "Best of %{previous_month}"}, %{}, scope())

      assert name == "Best of #{prev_month}"
    end

    test "leaves unknown placeholders as-is" do
      expect(SpotifyApi, :create_playlist, fn _scope, %LibraryPlaylist{title: "Hello %{unknown}"} = pl ->
        {:ok, created_playlist(pl.title)}
      end)

      assert {:ok, %{"playlist_name" => "Hello %{unknown}"}} =
               CreatePlaylist.execute(%{"name" => "Hello %{unknown}"}, %{}, scope())
    end
  end

  describe "execute/3 — output" do
    test "returns created_playlist_id and playlist_name" do
      expect(SpotifyApi, :create_playlist, fn _scope, pl ->
        {:ok, %LibraryPlaylist{provider: :spotify, playlist_id: "sp123", title: pl.title}}
      end)

      assert {:ok, %{"created_playlist_id" => "sp123", "playlist_name" => "My Playlist"}} =
               CreatePlaylist.execute(%{"name" => "My Playlist"}, %{}, scope())
    end

    test "propagates API error" do
      expect(SpotifyApi, :create_playlist, fn _scope, _pl -> {:error, :unauthorized} end)

      assert {:error, :unauthorized} =
               CreatePlaylist.execute(%{"name" => "My Playlist"}, %{}, scope())
    end
  end
end
