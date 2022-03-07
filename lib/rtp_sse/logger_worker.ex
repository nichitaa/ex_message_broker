defmodule RTP_SSE.LoggerWorker do
  @moduledoc """
  The actual workers (LoggerWorkers) that are parsing the tweet data,
  if a panic message is received it notify the parent `LoggerRouter` process to kill this
  child worker, otherwise it will just send the message to the socket (client) via `:gen_tcp.send(socket, msg)`
  """
  import Destructure
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  The `panic` message is just a non serializable JSON,
  that is in format of `"{\"message\": panic}"`
  """
  defp parse_tweet(data) do
    if data == "{\"message\": panic}" do
      {:kill_worker}
    else
      {:ok, json} = Poison.decode(data)
      {:ok, json, "tweet: worker-#{inspect(self())}" <> " " <> json["message"]["tweet"]["text"] <> "\r\n"}
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
    d(%{socket, routerPID, statisticWorkerPID}) = state

    start_time = :os.system_time(:milli_seconds)

    case parse_tweet(tweet_data) do
      {:kill_worker} ->
        GenServer.call(routerPID, {:terminate_logger_worker})
      {:ok, parsed, message} ->
        :gen_tcp.send(socket, message)
        TweetProcessor.Aggregator.add_tweet(%{raw_tweet: parsed, worker: "#{inspect(self())}"})
        RTP_SSE.HashtagsWorker.process_hashtags(tweet_data)
        Process.sleep(Enum.random(50..500))
        end_time = :os.system_time(:milli_seconds)
        execution_time = end_time - start_time
        GenServer.cast(statisticWorkerPID, {:add_execution_time, execution_time})
      _ -> nil
    end

    {:noreply, state}
  end
end
