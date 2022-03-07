defmodule TweetProcessor.Aggregator do

  import Destructure
  use GenServer
  require Logger

  @max_batch_size 1000

  def start_link(opts \\ []) do
    state = %{tweets: [], count: 0}
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Client API

  def add_tweet(tweet) do
    GenServer.cast(__MODULE__, {:add_tweet, tweet})
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:add_tweet, tweet}, state) do
    d(%{tweets, count}) = state
    count = count + 1
    tweets = [tweet | tweets]

    if count > @max_batch_size do
      TweetProcessor.DBService.bulk_insert(state.tweets)
      {:noreply, %{tweets: [], count: 0}}
    else
      {:noreply, d(%{tweets, count})}
    end

  end

end