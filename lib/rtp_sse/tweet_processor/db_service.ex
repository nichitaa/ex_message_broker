defmodule TweetProcessor.DBService do

  @moduledoc """
  TweetProcessor.DBService.insert(%{data: "test"})
  """

  import Destructure
  use GenServer
  require Logger

  @collection "tweets"
  @max_bulk_size 500

  def start_link(opts \\ []) do
    {:ok, connectionPID} = Mongo.start_link(url: "mongodb://localhost:27017/rtp_sse_db")
    GenServer.start_link(__MODULE__, d(%{connectionPID}), opts)
  end

  ## Client API

  def bulk_insert(data) do
    GenServer.cast(TweetProcessor.DBService, {:bulk_insert, data})
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:bulk_insert, data}, state) do

    d(%{connectionPID}) = state

    Logger.info("[DBService #{inspect(self())}] :bulk_insert #{inspect(length(data))} documents")

    data
    |> Enum.map(
         fn tweet ->
           Mongo.BulkOps.get_insert_one(tweet)
         end
       )
    |> Mongo.UnorderedBulk.write(connectionPID, @collection, @max_bulk_size)
    |> Stream.run()

    {:noreply, state}
  end

end