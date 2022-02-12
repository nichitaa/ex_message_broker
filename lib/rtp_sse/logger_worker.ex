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

  # Privates

  defp parse_opts(opts) do
    socket = opts[:socket]
    {socket}
  end

  defp parse_tweet(data) do
    if data == "{\"message\": panic}" do
      "[ReceiverWorker] ########################### GOT PANIC MESSAGE ###########################"
    else
      {:ok, json} = Poison.decode(data)
      json["message"]["tweet"]["text"]
    end
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:log_tweet, tweet_data}, state) do
    {socket} = state
    msg = parse_tweet(tweet_data)
    :gen_tcp.send(socket, msg)
    {:noreply, state}
  end
end
