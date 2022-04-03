defmodule Worker.Sentiment do

  import Destructure
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc """
  1. Calculate the sentiments score for given tweet and save the used variables as result
  2. Send the result to the linked `Aggregator`
  """
  @impl true
  def handle_cast({:work, tweet_data, poolPID}, state) do
    d(%{aggregatorPID}) = state

    # check for retweet
    case Utils.is_retweet(tweet_data) do
      {true, retweet} ->
        WorkerPool.route(poolPID, retweet)
      {false, nil} -> nil
      _ -> nil
    end

    punctuation = [".", ",", "?", "/", ":", ";", "!", "|"]

    tweet_text = tweet_data["message"]["tweet"]["text"]
    tweet_words =
      String.replace(tweet_text, punctuation, "")
      |> String.split(" ", trim: true)

    words_emotion_values =
      Enum.map(
        tweet_words,
        fn w ->
          score = Utils.EmotionValues.getWordEmotionalScore(w)
          score
        end
      )

    score = Statistics.mean(words_emotion_values)

    result = d(
      %{
        score_data: d(%{tweet_text, tweet_words, words_emotion_values, score}),
        original_tweet: tweet_data
      }
    )

    App.Aggregator.process_tweet_sentiments_score(aggregatorPID, result)

    {:noreply, state}
  end

end