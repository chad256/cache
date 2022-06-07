defmodule Cache.Store do
  @spec await_task() :: boolean() | atom()
  def exists? do
    case :ets.whereis(:function_registry) do
      :undefined -> false
      tid -> tid
    end
  end

  @spec new() :: atom()
  def new do
    :ets.new(:function_registry, [:named_table, :public])
  end

  @spec store(atom(), atom(), any()) :: boolean()
  def store(store, key, value) do
    :ets.insert(store, {key, value})
  end

  @spec get(atom(), atom()) :: list()
  def get(store, key) do
    :ets.lookup(store, key)
  end

  @spec boolean(atom(), atom()) :: boolean()
  def delete(store, key) do
    :ets.delete(store, key)
  end
end
