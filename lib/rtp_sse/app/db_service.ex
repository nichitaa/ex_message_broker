defmodule App.DBService do

  @moduledoc """
  MongoDB Service, used by the `Batcher` to perform a bulk
  insert of `tweets` and `users` into corresponding collections
  """

  import Destructure
  use GenServer
  require Logger
  import Statistics

  @mongo_srv Application.fetch_env!(:rtp_sse, :mongo_srv)
  @db_bulk_size Application.fetch_env!(:rtp_sse, :db_bulk_size)
  @db_tweets_collection Application.fetch_env!(:rtp_sse, :db_tweets_collection)
  @db_users_collection Application.fetch_env!(:rtp_sse, :db_users_collection)
  @db_users_engagements_collection Application.fetch_env!(:rtp_sse, :db_users_engagements_collection)

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

  def bulk_insert_users_engagements(pid, data) do
    GenServer.cast(pid, {:bulk_insert_users_engagements, data})
  end

  ## Privates
  defp bulk_insert(connection, collection_name, data) do
    Logger.info(
      "[DBService #{inspect(self())} bulk insert into #{inspect(collection_name)} (#{inspect(length(data))} docs)"
    )
    data
    |> Stream.map(
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

  @impl true
  def handle_cast({:bulk_insert_users_engagements, data}, state) do
    d(%{connectionPID}) = state

    # get all user ids
    ids = Map.keys(data)
    Logger.info(
      "[DBService #{inspect(self())} bulk insert into #{inspect(@db_users_engagements_collection)} (#{inspect(length(ids))} docs)"
    )

    # get all users with id from db
    list
    = Mongo.find(
        connectionPID,
        @db_users_engagements_collection,
        %{
          id_str: %{
            "$in" => ids
          }
        }
      )
      |> Enum.to_list()

    # perform a unordered bulk insert
    ids
    |> Stream.map(
         fn id ->
           # previous user data (from db)
           prev = Enum.find(list, fn map -> map["id_str"] == id end)

           # new user data
           user_data = Map.get(data, id)
           new_scores = Map.get(user_data, :scores)
           new_meta = Map.get(user_data, :meta)

           # if user present in db (update its data)
           if (prev != nil) do
             scores = prev["scores"]
             meta = prev["meta"]

             joined_scores = scores ++ new_scores
             joined_meta = meta ++ new_meta
             avg = Statistics.mean(joined_scores)

             # return a bulk operation (tb processed later on)
             Mongo.BulkOps.get_update_one(
               %{id_str: id},
               %{
                 "$set": %{
                   scores: joined_scores,
                   meta: joined_meta,
                   avg: avg
                 }
               }
             )

           else
             # insert new user + engagement data to db
             avg = Statistics.mean(new_scores)
             Mongo.BulkOps.get_insert_one(%{id_str: id, scores: new_scores, meta: new_meta, avg: avg})
           end
         end
       )
    |> Mongo.UnorderedBulk.write(connectionPID, @db_users_engagements_collection, @db_bulk_size)
    |> Stream.run()

    {:noreply, state}
  end

end