defmodule Utils do

  @mb_publish_command Application.fetch_env!(:change_stream, :mb_publish_command)
  @db_tweets_collection Application.fetch_env!(:change_stream, :db_tweets_collection)
  @db_users_collection Application.fetch_env!(:change_stream, :db_users_collection)

  def to_tweet_topic_event(tweet) do
    {:ok, serialized} = Poison.encode(
      %{
        "id": short_id(),
        "msg": tweet["original_tweet"]["message"]["tweet"]["text"],
        "priority": Enum.random(0..6)
      }
    )
    # using collection name as topic
    get_publish_command(@db_tweets_collection, serialized)
  end

  def to_user_topic_event(user) do
    {:ok, serialized} = Poison.encode(
      %{
        "id": short_id(),
        "msg": user["screen_name"],
        "priority": Enum.random(0..6)
      }
    )
    get_publish_command(@db_users_collection, serialized)
  end

  ## Privates
  defp get_publish_command(topic, serialized) do
    @mb_publish_command <> " " <> topic <> " " <> serialized <> "\r\n"
  end

  defp short_id() do
    String.slice(UUID.uuid4(), 0..2)
  end
end