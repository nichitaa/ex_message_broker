defmodule RTP_SSE.LoggerWorker do
  @moduledoc """
  The actual workers (LoggerWorkers) that are parsing the tweet data,
  if a panic message is received it notify the parent `LoggerRouter` process to kill this
  child worker, otherwise it will just send the message to the socket (client) via `:gen_tcp.send(socket, msg)`
  """

  use GenServer
  require Logger

  ## Client API

  def start_link(opts) do
    {socket, routerPID} = parse_opts(opts)
    GenServer.start_link(__MODULE__, %{socket: socket, routerPID: routerPID})
  end

  ## Privates

  defp parse_opts(opts) do
    socket = opts[:socket]
    routerPID = opts[:routerPID]
    {socket, routerPID}
  end

  @doc """
  The `panic` message is just a non serializable JSON,
  that is in format of `"{\"message\": panic}"`
  """
  defp parse_tweet(data) do
    if data == "{\"message\": panic}" do
      :kill_worker
    else
      {:ok, json} = Poison.decode(data)
      "tweet: worker-#{inspect(self())}" <> " " <> json["message"]["tweet"]["text"] <> "\r\n"
    end
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc """
  Used by the `LoggerRouter` to send the tweet data, it is parsing it
  and sending the tweet message to the socket (client) if it is a valid message,
  otherwise will ask the `LoggerRouter` parent process to kill this child worker
  """
  @impl true
  def handle_cast({:log_tweet, tweet_data}, state) do
    msg = parse_tweet(tweet_data)
    if msg == :kill_worker do
      GenServer.cast(state.routerPID, {:terminate_logger_worker, self()})
    else
      :gen_tcp.send(state.socket, msg)
      RTP_SSE.HashtagsWorker.process_hashtags(tweet_data)
      Process.sleep(Enum.random(50..500))
    end
    {:noreply, state}
  end

end
