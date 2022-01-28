defmodule RTP_SSE.LoggerWorker do
  use GenServer
  require Logger

  ## Client API

  def start_link(opts) do
    state = parse_opts(opts)
    Logger.info("[LoggerWorker] start_link socket - #{inspect(state)}")
    GenServer.start_link(__MODULE__, state)
  end

  def log_tweet(msg) do
    Logger.info("[LoggerWorker] received log tweet")
    GenServer.cast(__MODULE__, {:log_tweet, msg})
  end

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
  def handle_cast({:log_tweet, msg}, state) do
    {socket} = state

    # Logger.info(
    #   "[LoggerWorker] handle :log_tweet, msg - #{inspect(msg)} socket - #{inspect(socket)}"
    # )

    :gen_tcp.send(socket, msg)
    {:noreply, state}
  end
end
