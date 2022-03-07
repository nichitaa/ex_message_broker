defmodule TweetProcessor.Aggregator do

  import Destructure
  use GenServer
  require Logger

  @max_batch_size 1000 # tweets limit
  @flush_time 3000 # flush / save tweets every 3 sec

  def start_link(opts \\ []) do
    state = %{
      tweets: [],
      users: [],
      engagementWorkers: [],
      sentimentsWorkers: [],
      refs: %{},
      count: 0,
      index: 0
    }
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Client API

  @doc """
    Function used by `LoggerWorkers` in order to save tweet data to `Aggregator` state
  """
  def process_tweet(aggregatorPID, tweet_data) do
    GenServer.cast(aggregatorPID, {:process_tweet, tweet_data})
  end

  ## Privates

  defp flush_state_loop() do
    # Will constantly save tweets & users into database in a 3 sec timeframe,
    # using only the @max_batch_size will produce data loss if the last
    # batch has less elements then our max size
    selfPID = self()
    spawn(
      fn ->
        Process.sleep(@flush_time)
        GenServer.cast(selfPID, {:flush_state})
      end
    )
  end

  # Utility functions that transmits the data to be saved in database by `DBService`
  defp save_tweets(data) do
    TweetProcessor.DBService.bulk_insert_tweets(data)
  end

  defp save_users(data) do
    TweetProcessor.DBService.bulk_insert_users(data)
  end

  ## Callbacks

  @impl true
  def init(state) do
    flush_state_loop()
    send(self(), {:add_workers, 5})
    {:ok, state}
  end

  @impl true
  def handle_cast({:process_tweet, tweet_data}, state) do
    d(%{tweets, users, count, engagementWorkers, index, sentimentsWorkers}) = state

    # treating retweeted_status as separate tweet
    retweeted_tweet = tweet_data["message"]["tweet"]["retweeted_status"]
    if retweeted_tweet != nil do
      retweeted_tweet = %{
        "message" => %{
          "tweet" => retweeted_tweet
        }
      }
      GenServer.cast(self(), {:process_tweet, retweeted_tweet})
    end

    tweet =
      if length(engagementWorkers) > 0 and length(sentimentsWorkers) > 0 do
        # round robin for engagement and sentiments workers
        engagement_result
        = engagementWorkers
          |> Enum.at(rem(index, length(engagementWorkers)))
          |> GenServer.call({:engagement, tweet_data})

        sentiments_result
        = sentimentsWorkers
          |> Enum.at(rem(index, length(sentimentsWorkers)))
          |> GenServer.call({:sentiments, tweet_data})

        # update tweet
        d(
          %{
            engagement_result,
            sentiments_result,
            original: tweet_data,
            text: tweet_data["message"]["tweet"]["text"],
            engagement_score: engagement_result.score,
            sentiments_score: sentiments_result.score
          }
        )
      end

    count = count + 1
    user = tweet_data["message"]["tweet"]["user"]
    tweets = [tweet | tweets]
    users = [user | users]

    if count > @max_batch_size do
      save_tweets(tweets)
      save_users(users)
      {:noreply, %{state | tweets: [], users: [], count: 0}}
    else
      {:noreply, %{state | tweets: tweets, users: users, count: count}}
    end

  end

  @impl true
  def handle_cast({:flush_state}, state) do
    d(%{tweets, users, count}) = state
    if count > 0 do
      save_tweets(tweets)
      save_users(users)
    end
    flush_state_loop()
    {:noreply, %{state | tweets: [], users: [], count: 0}}
  end

  @impl true
  def handle_info({:add_workers, nr}, state) do
    d(%{engagementWorkers, sentimentsWorkers, refs}) = state

    engagement_workers =
      Enum.map(
        0..nr,
        fn _ ->
          {:ok, engagementWorkerPID} = DynamicSupervisor.start_child(
            TweetProcessor.EngagementWorkerSupervisor,
            TweetProcessor.EngagementWorker
          )
          engagementWorkerPID
        end
      )

    sentiments_workers = Enum.map(
      0..nr,
      fn _ ->
        {:ok, sentimentsWorkerPID} = DynamicSupervisor.start_child(
          TweetProcessor.SentimentWorkerSupervisor,
          TweetProcessor.SentimentWorker
        )
        sentimentsWorkerPID
      end
    )

    Logger.info("[Aggregator #{inspect(self())}] added #{inspect(nr)} engagement and statistics workers")

    # monitor both engagement and sentiments workers
    child_workers = Enum.concat(engagement_workers, sentiments_workers)

    refs = Enum.reduce(
      child_workers,
      refs,
      fn pid, acc ->
        ref = Process.monitor(pid)
        Map.put(acc, ref, pid)
      end
    )

    engagementWorkers = Enum.concat(engagementWorkers, engagement_workers)
    sentimentsWorkers = Enum.concat(sentimentsWorkers, sentiments_workers)

    {:noreply, %{state | refs: refs, engagementWorkers: engagementWorkers, sentimentsWorkers: sentimentsWorkers}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _workerPID, _reason}, state) do
    {_prev, refs} = Map.pop(state.refs, ref)
    {:noreply, %{state | refs: refs}}
  end

end