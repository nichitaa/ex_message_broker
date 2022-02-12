defmodule RTP_SSE.LoggerRouter do
  use GenServer
  require Logger

  def start_link(opts) do
    {socket} = parse_opts(opts)

    Logger.info("[LoggerRouter] start_link socket - #{inspect(socket)}")

    children = [
      DynamicSupervisor.start_child(
        RTP_SSE.LoggerWorkerDynamicSupervisor,
        {RTP_SSE.LoggerWorker, socket: socket}
      ),
      DynamicSupervisor.start_child(
        RTP_SSE.LoggerWorkerDynamicSupervisor,
        {RTP_SSE.LoggerWorker, socket: socket}
      )
    ]

    GenServer.start_link(__MODULE__, %{index: 0, children: children, socket: socket})
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

  @impl true
  def handle_call({:is_router_for_socket, socket}, _from, state) do
    match = state.socket == socket
    {:reply, match, state}
  end

  @impl true
  def handle_cast({:route, tweet_data}, state) do
    logger_workers = DynamicSupervisor.which_children(RTP_SSE.LoggerWorkerDynamicSupervisor)

    # Just in case we are spammed with multiple panic messages in a very small timeframe
    # and our dynamic supervisor does not succeed to start new workers in time
    # ! Was tested and seems like there are allways some workers in the list
    if length(logger_workers) > 0 do
      Enum.at(logger_workers, rem(state.index, length(logger_workers)))
      |> elem(1)
      |> GenServer.cast({:log_tweet, tweet_data})
    end

    {:noreply, %{index: state.index + 1, children: state.children, socket: state.socket}}
  end
end
