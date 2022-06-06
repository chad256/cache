defmodule Cache.Store do
  def store(store, key, value) do
    :ets.insert(store, {key, value})
  end

  def get(store, key) do
  end

  def delete(store, key) do
    :ets.delete(cache, key)
  end
end
