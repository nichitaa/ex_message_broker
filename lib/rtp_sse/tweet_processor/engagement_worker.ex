defmodule TweetProcessor.EngagementWorker do

  import Destructure
  use GenServer
  require Logger

  def start_link(_args, opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:engagement, tweet_data}, _from, state) do
    favorite_count = tweet_data["message"]["tweet"]["favorite_count"]
    retweet_count = tweet_data["message"]["tweet"]["retweet_count"]
    followers_count = tweet_data["message"]["tweet"]["user"]["followers_count"]
    # Logger.info("favorites: #{inspect(favorite_count)} retweets: #{inspect(retweet_count)}, followers: #{inspect(followers_count)}")

    score = calculate_score(favorite_count, retweet_count, followers_count)
    {:reply, score, state}
  end

  ## Privates

  defp calculate_score(favorites, retweets, 0) do
    (favorites + retweets) / 1
  end

  defp calculate_score(favorites, retweets, followers) do
    (favorites + retweets) / followers
  end

end