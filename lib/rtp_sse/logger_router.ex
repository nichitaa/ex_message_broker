defmodule RTP_SSE.LoggerRouter do
  @moduledoc """
  Starts several LoggerWorkers (workers) under the `RTP_SSE.LoggerWorkerDynamicSupervisor`,
  so in case a worker dies because of the panic message it will start new one.
  
  It keeps the counter (`index`), and socket into the state so that
  it can delegate the tweet for a specific worker in a round robin circular order
  """

  use GenServer
  require Logger

  def start_link(opts) do
    {socket} = parse_opts(opts)

    # start 2 LoggerWorkers passing the socket
    logger_workers =
      Enum.map(
        0..1,
        fn x ->
          {:ok, workerPID} =
            DynamicSupervisor.start_child(
              RTP_SSE.LoggerWorkerDynamicSupervisor,
              {RTP_SSE.LoggerWorker, socket: socket}
            )

          {:ok, workerPID}
        end
      )

    Logger.info(
      "[LoggerRouter] start_link SOCKET=#{inspect(socket)} logger_workers=#{inspect(logger_workers)}"
    )

    GenServer.start_link(__MODULE__, %{index: 0, socket: socket})
  end

  ## Private

  defp parse_opts(opts) do
    socket = opts[:socket]
    {socket}
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
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
  Asynchronously receives a tweet from the Receiver and it sends it to the next worker
  using the Round Robin load balancing technique
  
  request 1 -> worker 1
  request 2 -> worker 2
  request 3 -> worker 1
  ...
  """
  @impl true
  def handle_cast({:route, tweet_data}, state) do
    logger_workers = DynamicSupervisor.which_children(RTP_SSE.LoggerWorkerDynamicSupervisor)

    # Just in case we are spammed with multiple panic messages in a very small timeframe
    # and our dynamic supervisor does not succeed to start new workers in time
    # ! Was tested and seems like there are always some workers in the list
    if length(logger_workers) > 0 do
      Enum.at(logger_workers, rem(state.index, length(logger_workers)))
      |> elem(1)
      |> GenServer.cast({:log_tweet, tweet_data})
    end

    {:noreply, %{index: state.index + 1, socket: state.socket}}
  end

  @doc """
  5 tweets per 1 worker
  """
  @impl true
  def handle_cast({:autoscale, cnt}, state) do
    logger_workers = DynamicSupervisor.which_children(RTP_SSE.LoggerWorkerDynamicSupervisor)
    workers_no = length(logger_workers)
    Logger.info(
      "[LoggerRouter #{inspect(self())}] : auto-scale counter #{cnt}, workers no: #{workers_no}"
    )
    {:noreply, %{index: state.index + 1, socket: state.socket}}
  end
end
