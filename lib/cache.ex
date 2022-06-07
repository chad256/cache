defmodule Cache do
  use GenServer

  @type result ::
          {:ok, any()}
          | {:error, :timeout}
          | {:error, :not_registered}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @doc ~s"""
  Registers a function that will be computed periodically to update the cache.
  Arguments:
    - `fun`: a 0-arity function that computes the value and returns either
      `{:ok, value}` or `{:error, reason}`.
    - `key`: associated with the function and is used to retrieve the stored
    value.
    - `ttl` ("time to live"): how long (in milliseconds) the value is stored
      before it is discarded if the value is not refreshed.
    - `refresh_interval`: how often (in milliseconds) the function is
      recomputed and the new value stored. `refresh_interval` must be strictly
      smaller than `ttl`. After the value is refreshed, the `ttl` counter is
      restarted.
  The value is stored only if `{:ok, value}` is returned by `fun`. If `{:error,
  reason}` is returned, the value is not stored and `fun` must be retried on
  the next run.
  """
  @spec register_function(
          fun :: (() -> {:ok, any()} | {:error, any()}),
          key :: any,
          ttl :: non_neg_integer(),
          refresh_interval :: non_neg_integer()
        ) :: :ok | {:error, :already_registered}
  def register_function(fun, key, ttl, refresh_interval)
      when is_function(fun, 0) and is_integer(ttl) and ttl > 0 and
             is_integer(refresh_interval) and
             refresh_interval < ttl do
    GenServer.call(__MODULE__, {:register_function, %{fun: fun, key: key, ttl: ttl, refresh_interval: refresh_interval}})
  end

  @doc ~s"""
  Get the value associated with `key`.
  Details:
    - If the value for `key` is stored in the cache, the value is returned
      immediately.
    - If a recomputation of the function is in progress, the last stored value
      is returned.
    - If the value for `key` is not stored in the cache but a computation of
      the function associated with this `key` is in progress, wait up to
      `timeout` milliseconds. If the value is computed within this interval,
      the value is returned. If the computation does not finish in this
      interval, `{:error, :timeout}` is returned.
    - If `key` is not associated with any function, return `{:error,
      :not_registered}`
  """
  @spec get(any(), non_neg_integer()) :: result
  def get(key, timeout \\ 30_000) when is_integer(timeout) and timeout > 0 do
    GenServer.call(__MODULE__, {:get, %{key: key, timeout: timeout}})
  end

  ~s"""
  Create cache store if it doesn't already exist.
  """
  @impl true
  def init(_args) do
    cache =
      case Cache.Store.exists?() do
        false -> Cache.Store.new()
        cache -> cache
      end
    {:ok, cache}
  end

  ~s"""
  Create cache worker for function if the functon is not already registered.
  """
  @impl true
  def handle_call({:register_function, %{fun: fun, key: key, ttl: ttl, refresh_interval: refresh_interval}}, _from, cache) do
    reply =
      case Cache.Store.get(cache, key) do
        [{^key, _val}] -> {:error, :already_registered}
        [] -> Cache.Worker.start_link(%{fun: fun, key: key, ttl: ttl, refresh_interval: refresh_interval, cache: cache})
          :ok
      end
    {:reply, reply, cache}
  end

  ~s"""
  Return value if stored in cache or wait for task to compute if in progess.
  """
  @impl true
  def handle_call({:get, %{key: key, timeout: timeout}}, _from, cache) do
    response =
      case Cache.Store.get(cache, key) do
        [{^key, value}] -> value
        [] -> await_task(key, timeout)
      end
    {:reply, response, cache}
  end

  ~s"""
  Lookup cache worker associated with function.
    - If a worker does not exist the function is not registered and an error is returned.
    - If a worker does exist then wait for the task to be computed within the specified timeout window.
  """
  @spec await_task(atom(), non_neg_integer()) :: result
  defp await_task(key, timeout) do
    case Process.whereis(key) do
      nil -> {:error, :not_registered}
      _pid -> Cache.Worker.await_task(key, timeout)
    end
  end
end
