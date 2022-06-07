defmodule CacheTest do
  use ExUnit.Case
  doctest Cache

  test "cache registers a function that executes successfully" do
    fun = fn -> {:ok, 1 + 1} end
    Cache.register_function(fun, :one_plus_one, 100_000, 10_000)
    :timer.sleep(2000)
    val = Cache.get(:one_plus_one, 5_000)
    assert val == 2
  end

  test "cache does not store a value for function that returns an error" do
    fun = fn -> {:error, :reason} end
    Cache.register_function(fun, :two_plus_two, 100_000, 10_000)
    :timer.sleep(2000)
    val = Cache.get(:two_plus_two, 50_000)
    assert val == {:error, :timeout}
  end

  test "cache returns value when value is not stored but computaton is in progress" do
    fun = fn -> {:ok, 3 + 3} end
    Cache.register_function(fun, :three_plus_three, 100_000, 10_000)
    :timer.sleep(2000)
    Cache.Store.delete(:function_registry, :three_plus_three)
    send(:three_plus_three, :run_function)
    val = Cache.get(:three_plus_three, 5_000)
    assert val == 6
  end
end
