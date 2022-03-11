defmodule TweetProcessor.SentimentRouter do

  import Destructure
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    d(%{aggregatorPID}) = args

    state = d(%{aggregatorPID})
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Callbacks
  def init(state) do
    # initial start with 5 workers (per SSE stream or Router)
  end

end