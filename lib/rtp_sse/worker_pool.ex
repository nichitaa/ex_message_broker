defmodule WorkerPool do
  @moduledoc """
  Generic implementation of a worker pool
  Usage
  {:ok, pid} = DynamicSupervisor.start_child(
      YourWorkerPoolDynamicSupervisor,
      {
        WorkerPool,
        d(
          %{
            pool_supervisor_name: YourWorkerPoolDynamicSupervisor,
            worker: Worker.Sentiment, # worker type
            workerArgs: %{:some: "initial args for your workers"},
          }
        )
      }
    )
  """

  import Destructure
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    d(%{worker, workerArgs}) = args

    state = d(
      %{
        worker, # worker type
        pool_supervisor_name: args.pool_supervisor_name,
        workers: [],
        refs: %{},
        index: 0,
        workerArgs: workerArgs
      }
    )
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Client API

  def route(pid, data) do
    GenServer.cast(pid, {:route, data})
  end

  ## Callbacks

  def init(state) do
    # initial start with 5 workers
    Process.send_after(self(), {:add_workers, 5}, 50)
    {:ok, state}
  end

  @impl true
  def handle_cast({:route, data}, state) do
    d(%{workers, index}) = state

    if length(workers) > 0 do
      Enum.at(workers, rem(index, length(workers)))
      |> GenServer.cast({:work, data, self()})
    end
    {:noreply, %{state | index: index + 1}}
  end

  @impl true
  def handle_info({:add_workers, nr}, state) do
    d(%{workers, refs, worker, workerArgs, pool_supervisor_name}) = state

    new_workers =
      Enum.map(
        0..nr,
        fn x ->
          {:ok, workerPID} =
            DynamicSupervisor.start_child(
              pool_supervisor_name,
              {worker, workerArgs}
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
    Logger.info("[#{inspect(pool_supervisor_name)}] added #{nr} workers, current=#{length(workers)}")

    {:noreply, %{state | refs: refs, workers: workers}}
  end

  @impl true
  def handle_info({:remove_workers, nr}, state) do
    d(%{workers, pool_supervisor_name}) = state
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
      "[#{inspect(pool_supervisor_name)}] removed #{nr} workers, current=#{length(workers)}"
    )
    {:noreply, %{state | workers: workers}}
  end

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

  @impl true
  def handle_call({:kill_child_worker}, fromWorker, state) do
    # handle receiving kill requests from workers itself (used by logger workers)
    {workerPID, _ref} = fromWorker
    d(
      %{
        workers,
      }
    ) = state

    # actually terminate child worker process only after 3 sec, so it would process all messages
    Process.send_after(self(), {:worker_terminate_safe, workerPID}, 4000)

    # substitute the dead worker with a new one
    Process.send_after(self(), {:add_workers, 1}, 50)

    # remove worker from state so it will not receive more messages to its queue
    workers = List.delete(workers, workerPID)

    {:reply, nil, %{state | workers: workers}}
  end

  @impl true
  def handle_info({:worker_terminate_safe, workerPID}, state) do
    d(%{pool_supervisor_name}) = state
    case Process.info(workerPID, :message_queue_len) do
      {:message_queue_len, len} when len > 0 ->
        Process.send_after(self(), {:worker_terminate_safe, workerPID}, 4000)
      {:message_queue_len, len} when len == 0 ->
        DynamicSupervisor.terminate_child(pool_supervisor_name, workerPID)
      _ ->
        nil
    end
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, workerPID, _reason}, state) do
    {_prev, refs} = Map.pop(state.refs, ref)
    {:noreply, %{state | refs: refs}}
  end

end