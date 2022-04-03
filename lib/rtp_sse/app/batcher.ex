defmodule App.Batcher do

  import Destructure
  use GenServer
  require Logger

  @max_batch_size Application.fetch_env!(:rtp_sse, :max_batch_size)
  @batcher_flush_time Application.fetch_env!(:rtp_sse, :batcher_flush_time)

  def start_link(args, opts \\ []) do
    d(%{dbServicePID}) = args
    state = d(
      %{
        dbServicePID,
        tweets: [],
        users: [],
        count: 0
      }
    )
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Client API

  def add_tweet(pid, tweet_data) do
    GenServer.cast(pid, {:add_tweet, tweet_data})
  end

  ## Privates

  defp flush_state_loop() do
    # Will constantly save tweets & users into database in a 3 sec timeframe,
    # using only the @max_batch_size will produce data loss if the last
    # batch has less elements then our max size
    selfPID = self()
    spawn(
      fn ->
        Process.sleep(@batcher_flush_time)
        GenServer.cast(selfPID, {:flush_state})
      end
    )
  end

  defp save_tweets(dbServicePID, data) do
    App.DBService.bulk_insert_tweets(dbServicePID, data)
  end

  defp save_users(dbServicePID, data) do
    App.DBService.bulk_insert_users(dbServicePID, data)
  end

  ## Callbacks

  @impl true
  def init(state) do
     flush_state_loop()
    {:ok, state}
  end

  @doc """
  Add a fully processed tweet (contains sentiments and engagements scores).
  Used by the linked `Aggregator` for the corresponding client
  """
  @impl true
  def handle_cast({:add_tweet, tweet_data}, state) do
    d(%{tweets, users, count, dbServicePID}) = state

    count = count + 1
    tweets = [tweet_data[:tweet] | tweets]
    users = [tweet_data[:user] | users]

    if count >= @max_batch_size do
      save_tweets(dbServicePID, tweets)
      save_users(dbServicePID, users)
      {:noreply, %{state | tweets: [], users: [], count: 0}}
    else
      {:noreply, %{state | tweets: tweets, users: users, count: count}}
    end

  end

  @impl true
  def handle_cast({:flush_state}, state) do
    d(%{tweets, users, count, dbServicePID}) = state

    if count > 0 do
      save_tweets(dbServicePID, tweets)
      save_users(dbServicePID, users)
    end

    flush_state_loop()
    {:noreply, %{state | tweets: [], users: [], count: 0}}
  end

end