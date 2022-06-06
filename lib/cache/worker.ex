defmodule Cache.Worker do
  use GenServer

  @impl GenServer
  def start_link(params) do
    GenServer.start_link(__MODULE__, params)
  end

  def init(%{ttl: ttl, refresh_interval: refresh_interval} = params) do
    store_function(params)
    Process.send_after(self(), :store_function, refresh_interval)
    delete_timer = Process.send_after(self(), :delete_function, ttl)
    {:ok, Map.put(params, delete_timer: delete_timer)}
  end

  def handle_info(:store_function, %{delete_timer: delete_timer} = params) do
    store_function(params)
    Process.cancel_timer(delete_timer)
    Process.send_after(self(), :store_function, refresh_interval)
    delete_timer = Process.send_after(self(), :delete_function, ttl)
    {:noreply, Map.put(params, delete_timer: delete_timer)}
  end

  def handle_info(:delete_function, params) do
    delete_function(params)
    {:noreply, params}
  end

  defp store_function(%{fun: fun, key: key, ttl: ttl, refresh_interval: refresh_interval, cache: cache}) do
    case fun |> Task.async() |> Task.await() do
      {:ok, value} -> Cache.Store.store(cache, key, value, ttl)
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_function(%{key: key, cache: cache}) do
    Cache.Store.delete(cache, key)
  end
end
