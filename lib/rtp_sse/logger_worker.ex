defmodule RTP_SSE.LoggerWorker do
  @moduledoc """
  The actual workers (LoggerWorkers) that are parsing the tweet data,
  if a panic message is received it will kill itself by raising an error,
  otherwise it will just send the message to the socket (client) via `:gen_tcp.send(socket, msg)`
  """

  use GenServer
  require Logger

  ## Client API

  def start_link(opts) do
    state = parse_opts(opts)
    Logger.info("[LoggerWorker] start_link SOCKET=#{inspect(state)}")
    GenServer.start_link(__MODULE__, state)
  end

  ## Privates

  defp parse_opts(opts) do
    socket = opts[:socket]
    {socket}
  end

  @doc """
  The `panic` message is just a non serializable JSON,
  that is in format of `"{\"message\": panic}"` and if it is received
  it will kill the worker, otherwise will return the `tweet.message.tweet.text` field
  """
  defp parse_tweet(data) do
    if data == "{\"message\": panic}" do
      # kill the worker by raising an error
      raise("################ PANIC :( ################")
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

  @doc """
  Used by the LoggerRouter to send the tweet data, it is parsing it
  and sending the tweet message to the socket (client)
  """
  @impl true
  def handle_cast({:log_tweet, tweet_data}, state) do
    {socket} = state
    msg = parse_tweet(tweet_data)
    :gen_tcp.send(socket, msg)
    {:noreply, state}
  end
end
