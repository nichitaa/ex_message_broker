defmodule TweetProcessor.Aggregator do

  import Destructure
  use GenServer
  require Logger

  @max_batch_size 1000 # tweets limit
  @flush_time 3000 # flush / save tweets every 3 sec

  def start_link(opts \\ []) do
    state = %{tweets: [], count: 0, refs: %{}, engagementWorkers: [], sentimentsWorkers: [], index: 0}
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Client API

  @doc """
    Function used by workers in order to save tweet to `Aggregator` state
  """
  def add_tweet(tweet) do
    GenServer.cast(__MODULE__, {:add_tweet, tweet})
  end

  ## Privates

  @doc """
    Will constantly save tweets to database in a 3 sec timeframe,
    using only the @max_batch_size will produce data loss if the last
    batch has less elements then our max size
  """
  defp flush_tweets_loop() do
    selfPID = self()
    spawn(
      fn ->
        Process.sleep(@flush_time)
        GenServer.cast(selfPID, {:flush_tweets})
      end
    )
  end

  @doc """
    Utility function that passes the data (tweets)
    to our DB service to save it into db
  """
  defp save_tweets(data) do
    TweetProcessor.DBService.bulk_insert(data)
  end

  ## Callbacks

  @impl true
  def init(state) do
    flush_tweets_loop()
    send(self(), {:add_workers, 5})
    {:ok, state}
  end

  @impl true
  def handle_cast({:add_tweet, tweet}, state) do
    d(%{tweets, count, engagementWorkers, index, sentimentsWorkers}) = state

    tweet_to_save = %{raw_tweet: tweet}

    tweet_to_save =
      if length(engagementWorkers) > 0 and length(sentimentsWorkers) > 0 do
        # round robin for engagement and sentiments workers
        engagement_result
        = engagementWorkers
          |> Enum.at(rem(index, length(engagementWorkers)))
          |> GenServer.call({:engagement, tweet})

        sentiments_result
        = sentimentsWorkers
          |> Enum.at(rem(index, length(sentimentsWorkers)))
          |> GenServer.call({:sentiments, tweet})

        # update tweet_to_save
        Map.merge(
          tweet_to_save,
          d(
            %{
              engagement_result,
              sentiments_result,
              engagement_score: engagement_result.score,
              sentiments_score: sentiments_result.score
            }
          )
        )
      end

    count = count + 1
    tweets = [tweet_to_save | tweets]

    if count > @max_batch_size do
      save_tweets(state.tweets)
      {:noreply, %{state | tweets: [], count: 0}}
    else
      {:noreply, %{state | tweets: tweets, count: count}}
    end

  end

  @impl true
  def handle_cast({:flush_tweets}, state) do
    d(%{tweets, count}) = state
    if count > 0 do
      save_tweets(tweets)
    end
    flush_tweets_loop()
    {:noreply, %{state | tweets: [], count: 0}}
  end

  @impl true
  def handle_info({:add_workers, nr}, state) do
    d(%{engagementWorkers, sentimentsWorkers, refs}) = state

    engagement_workers =
      Enum.map(
        0..nr,
        fn x ->
          {:ok, engagementWorkerPID} = DynamicSupervisor.start_child(
            TweetProcessor.EngagementWorkerSupervisor,
            TweetProcessor.EngagementWorker
          )
          engagementWorkerPID
        end
      )

    sentiments_workers = Enum.map(
      0..nr,
      fn x ->
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
  def handle_info({:DOWN, ref, :process, workerPID, _reason}, state) do
    {_prev, refs} = Map.pop(state.refs, ref)
    {:noreply, %{state | refs: refs}}
  end

end