defmodule TweetProcessor.SentimentsRouter do

  import Destructure
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    d(%{aggregatorPID}) = args
    state = d(%{aggregatorPID, workers: [], refs: %{}, index: 0})
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Client API

  def route(pid, tweet_data) do
    GenServer.cast(pid, {:route, tweet_data})
  end

  ## Callbacks
  def init(state) do
    # initial start with 5 workers (per SSE stream or Router)
    Process.send_after(self(), {:add_workers, 5}, 50)
    {:ok, state}
  end


  ## Sentiments-Workers handling methods

  @doc """
  Round-Robin load balancer for `SentimentsWorkers` workers
  """
  @impl true
  def handle_cast({:route, tweet_data}, state) do
    d(%{workers, index}) = state
    if length(workers) > 0 do
      Enum.at(workers, rem(index, length(workers)))
      |> GenServer.cast({:sentiments, tweet_data})
    end
    {:noreply, %{state | index: index + 1}}
  end

  @doc """
  Add a new workers controlled by this parent process
  """
  @impl true
  def handle_info({:add_workers, nr}, state) do
    d(%{aggregatorPID, workers, refs}) = state

    new_workers =
      Enum.map(
        0..nr,
        fn x ->
          {:ok, workerPID} =
            DynamicSupervisor.start_child(
              TweetProcessor.SentimentsWorkerDynamicSupervisor,
              {
                TweetProcessor.SentimentWorker,
                d(%{aggregatorPID})
              }
            )
          workerPID
        end
      )

    refs =
      Enum.reduce(
        workers,
        refs,
        fn pid, acc ->
          ref = Process.monitor(pid)
          Map.put(acc, ref, pid)
        end
      )

    workers = Enum.concat(workers, new_workers)
    Logger.info("[SentimentsRouter #{inspect(self())}] added #{nr} workers, current=#{length(workers)}")

    {:noreply, %{state | refs: refs, workers: workers}}
  end

  @doc """
  Remove x workers from state only
  """
  @impl true
  def handle_info({:remove_workers, nr}, state) do
    d(%{workers}) = state
    workers_to_be_removed = Enum.take(workers, nr)
    # terminate safely each worker process
    Enum.each(
      workers_to_be_removed,
      fn workerPID ->
        Process.send_after(self(), {:worker_terminate_safe, workerPID}, 4000)
      end
    )
    # remove workers from the state, so they will not receive more messages to queue
    workers = Enum.reject(workers, fn x -> x in workers_to_be_removed end)
    Logger.info(
      "[SentimentsRouter #{inspect(self())}] removed #{nr} workers, current=#{length(workers)}"
    )
    {:noreply, %{state | workers: workers}}
  end

  @doc """
  Autoscale the workers for this pool
  """
  @impl true
  def handle_cast({:autoscale, cnt}, state) do
    if(cnt > 0) do

      expect_workers_no = div(cnt, 5) + 1
      current_workers_no = length(state.workers)
      diff = expect_workers_no - current_workers_no

      case diff do
        n when n > 0 ->
          send(self(), {:add_workers, diff})
        n when n < 0 ->
          send(self(), {:remove_workers, -diff})
        _ ->
          nil
      end

    end
    {:noreply, state}
  end

  @doc """
  Safely terminate a worker process
  """
  @impl true
  def handle_info({:worker_terminate_safe, workerPID}, state) do
    case Process.info(workerPID, :message_queue_len) do
      {:message_queue_len, len} when len > 0 ->
        Process.send_after(self(), {:worker_terminate_safe, workerPID}, 4000)
      {:message_queue_len, len} when len == 0 ->
        DynamicSupervisor.terminate_child(TweetProcessor.SentimentsWorkerDynamicSupervisor, workerPID)
      _ ->
        nil
    end
    {:noreply, state}
  end

  @doc """
  Clean up the `refs` state for the dead worker
  """
  @impl true
  def handle_info({:DOWN, ref, :process, workerPID, _reason}, state) do
    {_prev, refs} = Map.pop(state.refs, ref)
    {:noreply, %{state | refs: refs}}
  end

end