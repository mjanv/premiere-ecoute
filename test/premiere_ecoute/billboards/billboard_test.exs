defmodule PremiereEcoute.Billboards.BillboardTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Billboards.Billboard
  
  setup do
    user = user_fixture()
    
    {:ok, %{user: user}}
  end

  describe "create/1" do
    test "creates a billboard with valid attributes", %{user: user} do
      attrs = %Billboard{
        title: "Test Billboard",
        user_id: user.id,
        submissions: [
          %{"pseudo" => "viewer1", "url" => "https://spotify.com/playlist/1"},
          %{"pseudo" => "viewer2", "url" => "https://spotify.com/playlist/2"}
        ],
        status: :created
      }

      assert {:ok, %Billboard{} = billboard} = Billboard.create(attrs)
      assert billboard.title == "Test Billboard"
      assert billboard.user_id == user.id
      assert billboard.status == :created
      assert length(billboard.submissions) == 2
      assert is_binary(billboard.billboard_id)
      assert String.length(billboard.billboard_id) == 8
    end

    test "fails with invalid attributes" do
      assert {:error, %Ecto.Changeset{} = changeset} = Billboard.create(%Billboard{})
      assert %{title: ["can't be blank"], user_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "submissions/1" do
    test "returns billboards containing submissions from a specific pseudo", %{user: user} do
      {:ok, billboard1} = Billboard.create(%Billboard{
        title: "Billboard 1",
        user_id: user.id,
        submissions: [
          %{"pseudo" => "target_user", "url" => "https://spotify.com/playlist/1"},
          %{"pseudo" => "other_user", "url" => "https://spotify.com/playlist/2"}
        ],
        status: :created
      })

      {:ok, _billboard2} = Billboard.create(%Billboard{
        title: "Billboard 2", 
        user_id: user.id,
        submissions: [
          %{"pseudo" => "other_user", "url" => "https://spotify.com/playlist/3"}
        ],
        status: :created
      })

      {:ok, billboard3} = Billboard.create(%Billboard{
        title: "Billboard 3",
        user_id: user.id,
        submissions: [
          %{"pseudo" => "some_user", "url" => "https://spotify.com/playlist/4"},
          %{"pseudo" => "target_user", "url" => "https://spotify.com/playlist/5"},
          %{"pseudo" => "another_user", "url" => "https://spotify.com/playlist/6"}
        ],
        status: :created
      })

      billboards = Billboard.submissions("target_user")

      assert length(billboards) == 2
      
      billboard_ids = Enum.map(billboards, & &1.billboard_id)
      assert billboard1.billboard_id in billboard_ids
      assert billboard3.billboard_id in billboard_ids

      for billboard <- billboards do
        assert Enum.all?(billboard.submissions, fn s -> s["pseudo"] == "target_user" end)
      end
    end

    test "returns empty list when pseudo not found", %{user: user} do
      {:ok, _billboard} = Billboard.create(%Billboard{
        title: "Test Billboard",
        user_id: user.id,
        submissions: [
          %{"pseudo" => "user1", "url" => "https://spotify.com/playlist/1"},
          %{"pseudo" => "user2", "url" => "https://spotify.com/playlist/2"}
        ],
        status: :created
      })

      result = Billboard.submissions("nonexistent_user")
      assert result == []
    end
  end
end