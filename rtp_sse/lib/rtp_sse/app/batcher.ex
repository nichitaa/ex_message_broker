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
        count: 0,
        timer: nil
      }
    )
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Client API

  def add_tweet(pid, tweet_data) do
    GenServer.cast(pid, {:add_tweet, tweet_data})
  end

  ## Privates

  defp save_tweets(dbServicePID, data) do
    App.DBService.bulk_insert_tweets(dbServicePID, data)
  end

  defp save_users(dbServicePID, data) do
    App.DBService.bulk_insert_users(dbServicePID, data)
  end

  ## Callbacks

  @impl true
  def init(state) do
    # initiate a new timer
    timer = Process.send_after(self(), :flush_state, @batcher_flush_time)
    {:ok, %{state | timer: timer}}
  end

  @doc """
  Add a fully processed tweet (contains sentiments and engagements scores).
  Used by the linked `Aggregator` for the corresponding client
  """
  @impl true
  def handle_cast({:add_tweet, tweet_data}, state) do
    d(%{tweets, users, count, dbServicePID, timer}) = state

    count = count + 1
    tweets = [tweet_data[:tweet] | tweets]
    users = [tweet_data[:user] | users]

    if count >= @max_batch_size do
      save_tweets(dbServicePID, tweets)
      save_users(dbServicePID, users)

      # restart the timer if the tweets and users are processed because of size limit
      Process.cancel_timer(timer)
      timer = Process.send_after(self(), :flush_state, @batcher_flush_time)

      {:noreply, %{state | tweets: [], users: [], count: 0, timer: timer}}
    else
      {:noreply, %{state | tweets: tweets, users: users, count: count}}
    end

  end

  @impl true
  def handle_info(:flush_state, state) do
    d(%{tweets, users, count, dbServicePID, timer}) = state

    if count > 0 do
      save_tweets(dbServicePID, tweets)
      save_users(dbServicePID, users)
    end

    timer = Process.send_after(self(), :flush_state, @batcher_flush_time)
    {:noreply, %{state | tweets: [], users: [], count: 0, timer: timer}}
  end

end