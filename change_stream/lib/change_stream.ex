defmodule ChangeStream do
  use Application
  require Logger

  @mongo_srv Application.fetch_env!(:change_stream, :mongo_srv)
  @db_tweets_collection Application.fetch_env!(:change_stream, :db_tweets_collection)
  @db_users_collection Application.fetch_env!(:change_stream, :db_users_collection)
  @db_users_engagements_collection Application.fetch_env!(:change_stream, :db_users_engagements_collection)


  @impl true
  def start(_type, _args) do
    Logger.info("Starting ChangeStream application")

    children = [
      {
        Mongo,
        name: :mongo,
        url: @mongo_srv,
        pool_size: 10
      },
      # Assign a watcher for each collection
      Supervisor.child_spec({Handler, [name: TweetsHandler, collection: @db_tweets_collection]}, id: TweetsHandler),
      Supervisor.child_spec({Handler, [name: UsersHandler, collection: @db_users_collection]}, id: UsersHandler),
      Supervisor.child_spec(
        {Handler, [name: UsersEngagementsHandler, collection: @db_users_engagements_collection]},
        id: UsersEngagementsHandler
      ),
    ]
    opts = [strategy: :one_for_one, name: ChangeStream.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
