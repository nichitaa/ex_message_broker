defmodule RTP_SSE.LoggerRouter do
  @moduledoc """
  Starts several LoggerWorkers (workers) under the `RTP_SSE.LoggerWorkerDynamicSupervisor`,

  It keeps the counter (`index`), socket, refs (for monitoring child workers),
  workers (actual LoggerWorkers) into the state so that it can delegate
  the tweet for a specific worker in a round robin circular order
  """

  use GenServer
  require Logger

  def start_link(opts) do
    {socket} = parse_opts(opts)
    {:ok, statisticWorkerPID} =
      DynamicSupervisor.start_child(
        RTP_SSE.StatisticWorkerDynamicSupervisor,
        {RTP_SSE.StatisticWorker, %{}}
      )
    # Logger.info("[LoggerRouter] start_link SOCKET=#{inspect(socket)}")
    GenServer.start_link(
      __MODULE__,
      %{index: 0, socket: socket, refs: %{}, workers: [], statisticWorkerPID: statisticWorkerPID}
    )
  end

  ## Private

  defp parse_opts(opts) do
    socket = opts[:socket]
    {socket}
  end

  ## Callbacks

  @impl true
  def init(state) do
    # initial start of 5 workers per router process
    send(self(), {:add_logger_workers, 5})
    {:ok, state}
  end

  @doc """
  Asynchronously receives a tweet from the Receiver and it sends it to the next worker
  using the Round Robin load balancing technique

  request 1 -> worker 1
  request 2 -> worker 2
  request 3 -> worker 1
  ...
  """
  @impl true
  def handle_cast({:route, tweet_data}, state) do
    if length(state.workers) > 0 do
      Enum.at(state.workers, rem(state.index, length(state.workers)))
      |> GenServer.cast({:log_tweet, tweet_data})
    end
    {
      :noreply,
      %{
        index: state.index + 1,
        socket: state.socket,
        refs: state.refs,
        workers: state.workers,
        statisticWorkerPID: state.statisticWorkerPID
      }
    }
  end

  @doc """
  Removes the worker from state so it will not receive any more tweets to the message queue,
  and after a delay of 3 seconds terminates the worker process for real with `Supervisor.terminate_child`,
  instead it created a new worker process and links it to the current router process,
  we can not just raise an error in worker because it will force the Supervisor to restart
  the worker and we just can not find out what is the PID of the newly restarted worker
  to link to this specific router
  """
  @impl true
  def handle_cast({:terminate_logger_worker, workerPID}, state) do
    # actually terminate child worker process only after 3 sec, so it would process all messages
    Process.send_after(self(), {:kill_child_worker, workerPID}, 4000)

    {:ok, newWorkerPID} =
      DynamicSupervisor.start_child(
        RTP_SSE.LoggerWorkerDynamicSupervisor,
        {RTP_SSE.LoggerWorker, socket: state.socket, routerPID: self()}
      )

    ref = Process.monitor(newWorkerPID)
    refs = Map.put(state.refs, ref, newWorkerPID)

    workers = List.delete(state.workers, workerPID)
    workers = Enum.concat(workers, [newWorkerPID])

    {
      :noreply,
      %{
        index: state.index,
        socket: state.socket,
        refs: refs,
        workers: workers,
        statisticWorkerPID: state.statisticWorkerPID
      }
    }
  end

  @doc """
    Recursively check that a worker has no more unprocessed message inside queue,if so, terminate it
  """
  @impl true
  def handle_info({:kill_child_worker, workerPID}, state) do
    case Process.info(workerPID, :message_queue_len) do
      {:message_queue_len, len} when len > 0 ->
        # Logger.info("[LoggerRouter #{inspect(self())}] KILL WORKER=#{inspect(workerPID)} AFTER SOME TIME | q=#{len}")
        Process.send_after(self(), {:kill_child_worker, workerPID}, 4000)
      {:message_queue_len, len} when len == 0 ->
        # Logger.info("[LoggerRouter #{inspect(self())}] KILL WORKER=#{inspect(workerPID)} | q=#{len}")
        DynamicSupervisor.terminate_child(RTP_SSE.LoggerWorkerDynamicSupervisor, workerPID)
      _ ->
      # Logger.info("[LoggerRouter #{inspect(self())}] WORKER ALREADY KILLED #{inspect(workerPID)}")
    end
    {:noreply, state}
  end

  @doc """
  Only used by the `RTP_SSE.Command` when checking for a duplicate
  `twitter` command from the client, so it will not recreate a new
  LoggerRouter process if one already exists
  """
  @impl true
  def handle_call({:is_router_for_socket, socket}, _from, state) do
    match = state.socket == socket
    {:reply, match, state}
  end

  @doc """
  Used by the TweetsCounter to send the nr of tweets per timeframe (1sec)
  Distribution: 5 tweets per 1 worker
  """
  @impl true
  def handle_cast({:autoscale, cnt}, state) do
    if(cnt > 0) do
      expect_workers_no = div(cnt, 5)
      current_workers_no = length(state.workers)
      diff = expect_workers_no - current_workers_no
      case diff do
        n when n > 0 ->
          # add some new workers
          send(self(), {:add_logger_workers, diff})
        n when n < 0 ->
          # remove some workers
          send(self(), {:remove_logger_workers, -diff})
        _ ->
        # Logger.info("[LoggerRouter #{inspect(self())}] leaving same number of workers=#{length(state.workers)}")
      end
    end
    {
      :noreply,
      %{
        index: state.index,
        socket: state.socket,
        refs: state.refs,
        workers: state.workers,
        statisticWorkerPID: state.statisticWorkerPID
      }
    }
  end



  @doc """
  Add and link some (nr) LoggerWorkers to the router process
  """
  @impl true
  def handle_info({:add_logger_workers, nr}, state) do
    logger_workers =
      Enum.map(
        0..nr,
        fn x ->
          {:ok, workerPID} =
            DynamicSupervisor.start_child(
              RTP_SSE.LoggerWorkerDynamicSupervisor,
              {
                RTP_SSE.LoggerWorker,
                socket: state.socket,
                routerPID: self(),
                statisticWorkerPID: state.statisticWorkerPID
              }
            )
          workerPID
        end
      )
    refs = Enum.reduce(
      logger_workers,
      state.refs,
      fn pid, acc ->
        ref = Process.monitor(pid)
        Map.put(acc, ref, pid)
      end
    )
    workers = Enum.concat(state.workers, logger_workers)
    Logger.info("[LoggerRouter #{inspect(self())}] number of workers after add=#{length(workers)}")
    {
      :noreply,
      %{
        index: state.index,
        socket: state.socket,
        refs: refs,
        workers: workers,
        statisticWorkerPID: state.statisticWorkerPID
      }
    }
  end

  @doc """
  Terminates first nr LoggerWorkers from current router process
  """
  @impl true
  def handle_info({:remove_logger_workers, nr}, state) do
    logger_workers_to_remove =
      Enum.take(state.workers, nr)
    Enum.each(
      logger_workers_to_remove,
      fn workerPID ->
        Process.send_after(self(), {:kill_child_worker, workerPID}, 4000)
      end
    )
    workers = Enum.reject(state.workers, fn x -> x in logger_workers_to_remove end)
    Logger.info("[LoggerRouter #{inspect(self())}] number of workers after remove=#{length(workers)}")
    {
      :noreply,
      %{
        index: state.index,
        socket: state.socket,
        refs: state.refs,
        workers: workers,
        statisticWorkerPID: state.statisticWorkerPID
      }
    }
  end

  @doc """
  Handles the LoggerWorker process crash `DynamicSupervisor.terminate_child(RTP_SSE.LoggerWorkerDynamicSupervisor, workerPID)`
  It removes the monitor reference from state
  """
  @impl true
  def handle_info({:DOWN, ref, :process, workerPID, _reason}, state) do
    {_prev, refs} = Map.pop(state.refs, ref)
    GenServer.cast(state.statisticWorkerPID, {:add_worker_crash})
    {
      :noreply,
      %{
        index: state.index,
        socket: state.socket,
        refs: refs,
        workers: state.workers,
        statisticWorkerPID: state.statisticWorkerPID
      }
    }
  end
end
