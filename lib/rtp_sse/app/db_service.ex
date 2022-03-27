defmodule App.DBService do

  @moduledoc """
  MongoDB Service, used by the `Batcher` to perform a bulk
  insert of `tweets` and `users` into corresponding collections
  """

  import Destructure
  use GenServer
  require Logger

  @mongo_srv Application.fetch_env!(:rtp_sse, :mongo_srv)
  @db_bulk_size Application.fetch_env!(:rtp_sse, :db_bulk_size)
  @db_tweets_collection Application.fetch_env!(:rtp_sse, :db_tweets_collection)
  @db_users_collection Application.fetch_env!(:rtp_sse, :db_users_collection)

  def start_link(args, opts \\ []) do
    d(%{statisticWorkerPID}) = args
    {:ok, connectionPID} = Mongo.start_link(url: @mongo_srv)
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
    |> Mongo.UnorderedBulk.write(connection, collection_name, @db_bulk_size)
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
    bulk_insert(connectionPID, @db_tweets_collection, data)
    end_time = :os.system_time(:milli_seconds)
    time_diff = end_time - start_time
    GenServer.cast(statisticWorkerPID, {:add_bulk_tweets_stats, time_diff, length(data)})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:bulk_insert_users, data}, state) do
    d(%{connectionPID, statisticWorkerPID}) = state
    start_time = :os.system_time(:milli_seconds)
    bulk_insert(connectionPID, @db_users_collection, data)

    end_time = :os.system_time(:milli_seconds)
    time_diff = end_time - start_time
    GenServer.cast(statisticWorkerPID, {:add_bulk_users_stats, time_diff, length(data)})
    {:noreply, state}
  end

end