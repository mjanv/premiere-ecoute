defmodule PremiereEcouteCore.CacheTest do
  use ExUnit.Case, async: false

  alias PremiereEcouteCore.Cache

  setup do
    start_supervised({Cache, name: :cache})

    :ok
  end

  describe "put/3" do
    test "write a value in an existing cache" do
      {:ok, true} = Cache.put(:cache, :a, 1)
    end

    test "does not write a value in a existing cache" do
      {:error, :no_cache} = Cache.put(:unknown, :a, 1)
    end
  end

  describe "get/2" do
    test "read a value in an existing cache" do
      {:ok, _} = Cache.put(:cache, :a, 1)

      {:ok, value} = Cache.get(:cache, :a)

      assert value == 1
    end

    test "read a unknown value in an existing cache" do
      {:ok, value} = Cache.get(:cache, :a)

      assert value == nil
    end
  end

  describe "clear/1" do
    test "remove all keys" do
      {:ok, _} = Cache.put(:cache, :a, 1)
      {:ok, _} = Cache.put(:cache, :b, 2)
      {:ok, _} = Cache.put(:cache, :c, 3)

      Cache.clear(:cache)

      {:ok, a} = Cache.get(:cache, :a)
      {:ok, b} = Cache.get(:cache, :b)
      {:ok, c} = Cache.get(:cache, :c)

      assert {a, b, c} == {nil, nil, nil}
    end
  end
end
