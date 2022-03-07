defmodule TweetProcessor.SentimentWorker do

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
  def handle_call({:sentiments, tweet_data}, _from, state) do

    punctuation = [".", ",", "?", "/", ":", ";", "!", "|"]

    tweet_text = tweet_data["message"]["tweet"]["text"]
    tweet_words =
      String.replace(tweet_text, punctuation, "")
      |> String.split(" ", trim: true)

    words_emotion_values =
      Enum.map(
        tweet_words,
        fn w ->
          score = TweetProcessor.EmotionValues.getWordEmotionalScore(w)
          score
        end
      )

    score = Statistics.mean(words_emotion_values)

    result = d(%{tweet_text, tweet_words, words_emotion_values, score})

    {:reply, result, state}
  end

end