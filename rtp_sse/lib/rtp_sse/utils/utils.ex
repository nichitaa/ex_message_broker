defmodule Utils do

  @mb_publish_command Application.fetch_env!(:rtp_sse, :mb_publish_command)
  @mb_tweets_topic Application.fetch_env!(:rtp_sse, :mb_tweets_topic)
  @mb_user_topic Application.fetch_env!(:rtp_sse, :mb_user_topic)

  @doc """
  if it is retweet will return a tuple {true, retweet}
  otherwise {false, nil}
  """
  def is_retweet(tweet) do
    # treating retweeted_status as separate tweet
    retweeted_tweet = tweet["message"]["tweet"]["retweeted_status"]
    if retweeted_tweet != nil do
      # make the retweet object have the original tweet properties
      retweeted_tweet = %{
        "is_retweet" => true,
        "message" => %{
          "tweet" => retweeted_tweet
        }
      }
      {true, retweeted_tweet}
    else
      {false, nil}
    end
  end

  def to_tweet_topic_event(tweet) do
    {:ok, serialized} = Poison.encode(
      %{
        "id": tweet["message"]["tweet"]["id_str"],
        "msg": tweet["message"]["tweet"]["text"]
      }
    )
    publish = @mb_publish_command <> " " <> @mb_tweets_topic <> " " <> serialized <> "\r\n"
    publish
  end

  def to_user_topic_event(tweet) do
    {:ok, serialized} = Poison.encode(
      %{
        "id": tweet["message"]["tweet"]["user"]["id_str"],
        "msg": tweet["message"]["tweet"]["user"]["screen_name"]
      }
    )
    publish = @mb_publish_command <> " " <> @mb_user_topic <> " " <> serialized <> "\r\n"
    publish
  end
end