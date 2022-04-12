defmodule Worker.Engagement do

  import Destructure
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  ## Privates

  defp calculate_score(favorites, retweets, 0) do
    (favorites + retweets) / 1
  end

  defp calculate_score(favorites, retweets, followers) do
    (favorites + retweets) / followers
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc """
  1. Calculate the engagement score for given tweet and save the used variables as result
  2. Send the result to the linked `Aggregator`
  """
  @impl true
  def handle_cast({:work, tweet_data, poolPID}, state) do
    d(%{aggregatorPID, userEngagementAggregatorPID}) = state

    # check for retweet
    case Utils.is_retweet(tweet_data) do
      {true, retweet} ->
        WorkerPool.route(poolPID, retweet)
      {false, nil} -> nil
      _ -> nil
    end

    favorite_count = tweet_data["message"]["tweet"]["favorite_count"]
    retweet_count = tweet_data["message"]["tweet"]["retweet_count"]
    followers_count = tweet_data["message"]["tweet"]["user"]["followers_count"]
    user_id = tweet_data["message"]["tweet"]["user"]["id_str"]

    score = calculate_score(favorite_count, retweet_count, followers_count)

    result = d(
      %{
        score_data: d(%{favorite_count, retweet_count, followers_count, score}),
        original_tweet: tweet_data
      }
    )

    App.UserEngagement.add_user_engagement(userEngagementAggregatorPID, user_id, score, result)
    App.Aggregator.process_tweet_engagement_score(aggregatorPID, result)
    {:noreply, state}
  end

end