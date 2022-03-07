defmodule TweetProcessor.Aggregator do

  import Destructure
  use GenServer
  require Logger

  @max_batch_size 1000 # tweets limit
  @flush_time 3000 # flush / save tweets every 3 sec

  def start_link(opts \\ []) do
    state = %{tweets: [], count: 0}
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
    {:ok, state}
  end

  @impl true
  def handle_cast({:add_tweet, tweet}, state) do
    d(%{tweets, count}) = state
    count = count + 1
    tweets = [tweet | tweets]

    if count > @max_batch_size do
      save_tweets(state.tweets)
      {:noreply, %{tweets: [], count: 0}}
    else
      {:noreply, d(%{tweets, count})}
    end

  end

  @impl true
  def handle_cast({:flush_tweets}, state) do
    d(%{tweets, count}) = state
    if count > 0 do
      save_tweets(tweets)
    end
    flush_tweets_loop()
    {:noreply, %{tweets: [], count: 0}}
  end

end