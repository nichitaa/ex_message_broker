defmodule MessageBroker do

  @moduledoc """
  # dev test
  pub tweets {"id":"1","msg":"tweet 1"}
  pub tweets {"id":"2","msg":"tweet 2"}
  pub tweets {"id":"3","msg":"tweet 3"}
  pub users {"id":"1","msg":"usr 1"}
  """


  use Application
  require Logger

  @port Application.fetch_env!(:message_broker, :port)

  @impl true
  def start(_type, _args) do
    Logger.info("Starting MessageBroker")

    children = [
      # Controller
      {Controller, name: Controller},
      # Server
      {Task.Supervisor, name: Server.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> Server.accept(@port) end}, restart: :permanent)
    ]
    opts = [strategy: :one_for_one, name: RTP_SSE.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
