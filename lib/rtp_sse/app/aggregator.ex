defmodule App.Aggregator do

  @moduledoc """
  When receiving a score from SentimentWorker or EngagementWorker
  will check if the tweet is already contained in the opposite Map,
  if so then "aggregate" the date and pass it to `Batcher` and remove it
  from `Aggregator` internal state. If the tweet is not present
  in the opposite Map then just wait for the worker to finish and call the
  corresponding method and make the check again
  """

  import Destructure
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    d(%{batcherPID}) = args
    state = d(
      %{
        batcherPID,
        tweets_sentiment_scores: %{},
        tweets_engagement_scores: %{},
      }
    )
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Client API

  def process_tweet_sentiments_score(pid, data) do
    GenServer.cast(pid, {:process_sentiments_score, data})
  end

  def process_tweet_engagement_score(pid, data) do
    GenServer.cast(pid, {:process_engagement_score, data})
  end

  ## Privates
  def send_tweet_to_batcher(batcherPID, tw_id, original_tweet, engagement, sentiments, user) do
    App.Batcher.add_tweet(
      batcherPID,
      d(
        %{
          user,
          tweet: d(
            %{
              tw_id,
              original_tweet,
              sentiments_data: sentiments,
              sentiments_score: sentiments[:score],
              engagement_data: engagement,
              engagement_score: engagement[:score],
            }
          )
        }
      )
    )
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  def handle_cast({:process_engagement_score, data}, state) do
    d(
      %{
        tweets_sentiment_scores,
        tweets_engagement_scores,
        batcherPID,
      }
    ) = state

    original_tweet = data[:original_tweet]
    tw_id = original_tweet["message"]["tweet"]["id_str"]
    score_data = data[:score_data]
    user = data[:original_tweet]["message"]["tweet"]["user"]

    sentiment_score = Map.get(tweets_sentiment_scores, tw_id)

    if sentiment_score == nil do
      tweets_engagement_scores = Map.put(tweets_engagement_scores, tw_id, score_data)
      {:noreply, %{state | tweets_engagement_scores: tweets_engagement_scores}}
    else
      {sentiment_score, tweets_sentiment_scores} = Map.pop(tweets_sentiment_scores, tw_id)
      send_tweet_to_batcher(batcherPID, tw_id, original_tweet, score_data, sentiment_score, user)
      {:noreply, %{state | tweets_sentiment_scores: tweets_sentiment_scores}}
    end

  end

  def handle_cast({:process_sentiments_score, data}, state) do
    d(
      %{
        tweets_sentiment_scores,
        tweets_engagement_scores,
        batcherPID,
      }
    ) = state

    original_tweet = data[:original_tweet]
    tw_id = original_tweet["message"]["tweet"]["id_str"]
    score_data = data[:score_data]
    user = data[:original_tweet]["message"]["tweet"]["user"]

    engagement_score = Map.get(tweets_engagement_scores, tw_id)

    if engagement_score == nil do
      tweets_sentiment_scores = Map.put(tweets_sentiment_scores, tw_id, score_data)
      {:noreply, %{state | tweets_sentiment_scores: tweets_sentiment_scores}}
    else
      {engagement_score, tweets_engagement_scores} = Map.pop(tweets_engagement_scores, tw_id)
      send_tweet_to_batcher(batcherPID, tw_id, original_tweet, engagement_score, score_data, user)
      {:noreply, %{state | tweets_engagement_scores: tweets_engagement_scores}}
    end

  end

end