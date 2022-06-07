defmodule Cache.Store do
  def exists? do
    case :ets.whereis(:function_registry) do
      :undefined -> false
      tid -> tid
    end
  end

  def new do
    :ets.new(:function_registry, [:named_table, :public])
  end

  def store(store, key, value) do
    :ets.insert(store, {key, value})
  end

  def get(store, key) do
    :ets.lookup(store, key)
  end

  def delete(store, key) do
    :ets.delete(store, key)
  end
end
