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

    GenServer.start_link(__MODULE__, %{index: 0, children: children})
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
  def handle_cast({:route, msg}, state) do
    Enum.at(state.children, rem(state.index, length(state.children)))
    # get the second element (pid) from the tuple {:ok, pid}
    |> elem(1)
    |> GenServer.cast({:log_tweet, msg})

    {:noreply, %{index: state.index + 1, children: state.children}}
  end
end
