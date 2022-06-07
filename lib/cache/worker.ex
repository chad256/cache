defmodule Cache.Worker do
  use GenServer

  def start_link(%{key: key} = params) do
    GenServer.start_link(__MODULE__, params, [name: key])
  end

  def await_task(key, timeout) do
    GenServer.call(key, {:await_task, timeout})
  end

  @impl true
  def init(params) do
    Process.send_after(self(), :run_function, 1000)
    {:ok, params}
  end

  ~s"""
  Wait for the function task to execute within the given timeout.
  """
  @impl true
  def handle_call({:await_task, timeout}, _from, %{task: task} = state) do
    response =
      case Task.yield(task, timeout) do
        {:ok, {:ok, value}} -> value
        _ -> {:error, :timeout}
      end
    {:reply, response, state}
  end


  ~s"""
  Create a task process to execute the function.
  """
  @impl true
  def handle_info(:run_function, %{fun: fun} = state) do
    task = Task.Supervisor.async_nolink(Cache.TaskSupervisor, fun)
    {:noreply, Map.put(state, :task, task)}
  end

  ~s"""
  Delete function from cache.
  """
  @impl true
  def handle_info(:delete_function, %{key: key, cache: cache} = state) do
    Cache.Store.delete(cache, key)
    {:noreply, state}
  end

  ~s"""
  Store value in cache when function executes successfully.
  Cancel existing timer scheduled to expire cache.
  Schedule cache to refresh after given interval.
  Schedule new timer to expire value if cache not refreshed before time to live.
  """
  @impl true
  def handle_info({ref, {:ok, value}}, %{key: key, cache: cache, ttl: ttl, refresh_interval: refresh_interval} = state) do
    Process.demonitor(ref, [:flush])
    Cache.Store.store(cache, key, value)
    if Map.has_key?(state, :delete_timer) do
      Process.cancel_timer(state[:delete_timer])
    end
    Process.send_after(self(), :run_function, refresh_interval)
    delete_timer = Process.send_after(self(), :delete_function, ttl)
    {:noreply, Map.put(state, :delete_timer, delete_timer)}
  end

  ~s"""
  Retry function execution if task fails.
  """
  @impl true
  def handle_info({ref, {:error, _reason}}, %{fun: fun} = state) do
    Process.demonitor(ref, [:flush])
    task = Task.Supervisor.async_nolink(Cache.TaskSupervisor, fun)
    {:noreply, %{state | task: task}}
  end

  ~s"""
  Retry function execution if task process crashes.
  """
  @impl true
  def handle_info({:DOWN, _ref, _, _pid, _reason}, %{fun: fun} = state) do
    task = Task.Supervisor.async_nolink(Cache.TaskSupervisor, fun)
    {:noreply, %{state | task: task}}
  end
end
