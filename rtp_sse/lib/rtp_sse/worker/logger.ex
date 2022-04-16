defmodule Worker.Logger do

  import Destructure
  use GenServer
  require Logger

  @logger_min_sleep Application.fetch_env!(:rtp_sse, :logger_min_sleep)
  @logger_max_sleep Application.fetch_env!(:rtp_sse, :logger_max_sleep)
  @ignore_panic_message Application.fetch_env!(:rtp_sse, :ignore_panic_message)

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:work, tweet_data, poolPID}, state) do

    start_time = :os.system_time(:milli_seconds)
    d(
      %{socket, sentimentWorkerPoolPID, engagementWorkerPoolPID, statisticWorkerPID, hashtagWorkerPID, message_broker}
    ) = state

    case parse_tweet(tweet_data) do
      {:kill_worker} ->
        # request to kill itself & update statistics
        if (@ignore_panic_message == false) do
          GenServer.call(poolPID, {:kill_child_worker})
        end
        GenServer.call(statisticWorkerPID, {:add_worker_crash})
      {:ok, parsed, message} ->
        # send the tweet message to client terminal
        :gen_tcp.send(socket, message)

        # publish `tweet` and `users` to the message broker
        :gen_tcp.send(message_broker, Utils.to_tweet_topic_event(parsed))
        :gen_tcp.send(message_broker, Utils.to_user_topic_event(parsed))

        # send the tweet to the Sentiments & Engagement Pool of workers
        WorkerPool.route(engagementWorkerPoolPID, parsed)
        WorkerPool.route(sentimentWorkerPoolPID, parsed)

        # process statistics
        Process.sleep(Enum.random(@logger_min_sleep..@logger_max_sleep))
        end_time = :os.system_time(:milli_seconds)
        execution_time = end_time - start_time
        App.Hashtag.process_hashtags(hashtagWorkerPID, tweet_data)
        App.Statistic.add_execution_time(statisticWorkerPID, execution_time)

      _ -> nil
    end

    {:noreply, state}
  end

  ## Privates
  defp parse_tweet(data) do
    if data == "{\"message\": panic}" do
      {:kill_worker}
    else
      {:ok, json} = Poison.decode(data)
      {:ok, json, "tweet: worker-#{inspect(self())}" <> " " <> json["message"]["tweet"]["text"] <> "\r\n"}
    end
  end

end