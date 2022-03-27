defmodule App.DBService do

  @moduledoc """
  MongoDB Service, used by the `Batcher` to perform a bulk
  insert of `tweets` and `users` into corresponding collections
  """

  import Destructure
  use GenServer
  require Logger

  @tweets_collection "tweets" # collection name
  @users_collection "users"
  @max_bulk_size 50   # Mongo max bulk size for 200 documents bulk upload

  def start_link(args, opts \\ []) do
    d(%{statisticWorkerPID}) = args
    {:ok, connectionPID} = Mongo.start_link(url: "mongodb://localhost:27017/rtp_sse_db")
    GenServer.start_link(__MODULE__, d(%{connectionPID, statisticWorkerPID}), opts)
  end

  ## Client API

  def bulk_insert_tweets(pid, data) do
    GenServer.cast(pid, {:bulk_insert_tweets, data})
  end

  def bulk_insert_users(pid, data) do
    GenServer.cast(pid, {:bulk_insert_users, data})
  end

  ## Privates
  defp bulk_insert(connection, collection_name, data) do
    Logger.info(
      "[DBService #{inspect(self())} bulk insert into #{inspect(collection_name)} (#{inspect(length(data))} docs)"
    )
    data
    |> Enum.map(
         fn item ->
           Mongo.BulkOps.get_insert_one(item)
         end
       )
    |> Mongo.UnorderedBulk.write(connection, collection_name, @max_bulk_size)
    |> Stream.run()
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:bulk_insert_tweets, data}, state) do
    d(%{connectionPID, statisticWorkerPID}) = state
    start_time = :os.system_time(:milli_seconds)
    bulk_insert(connectionPID, @tweets_collection, data)
    end_time = :os.system_time(:milli_seconds)
    time_diff = end_time - start_time
    GenServer.cast(statisticWorkerPID, {:add_bulk_tweets_stats, time_diff, length(data)})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:bulk_insert_users, data}, state) do
    d(%{connectionPID, statisticWorkerPID}) = state
    start_time = :os.system_time(:milli_seconds)
    bulk_insert(connectionPID, @users_collection, data)

    end_time = :os.system_time(:milli_seconds)
    time_diff = end_time - start_time
    GenServer.cast(statisticWorkerPID, {:add_bulk_users_stats, time_diff, length(data)})
    {:noreply, state}
  end

end