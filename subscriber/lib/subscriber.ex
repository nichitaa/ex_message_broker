defmodule Subscriber do

  @moduledoc """
  A demo subscriber for the message broker
  """

  use Application
  require Logger

  @port Application.fetch_env!(:subscriber, :port)

  @impl true
  def start(_type, _args) do
    Logger.info("Starting Subscriber application")

    children = [
      {Task.Supervisor, name: SubClient.TaskSupervisor},
      # {SubClient, name: SubClient},
      Supervisor.child_spec({SubClient, [name: SubClientTweets, topic: "tweets"]}, id: SubClientTweets),
      Supervisor.child_spec({SubClient, [name: SubClientUsers, topic: "users"]}, id: SubClientUsers),
    ]
    opts = [strategy: :one_for_one, name: Subscriber.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
