defmodule Utils do
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
end