defmodule MessageBroker do

  @moduledoc """
  # dev test
  pub tweets {"id":"1", "priority": 3, "msg":"tweet 1"}
  pub tweets {"id":"2", "priority": 4, "msg":"tweet 2"}
  pub tweets {"id":"3", "priority": 2, "msg":"tweet 3"}
  pub tweets {"id":"4", "priority": 5, "msg":"tweet 4"}
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
      {Util.JsonLog, name: Util.JsonLog},
      # Server
      {Task.Supervisor, name: Server.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> Server.accept(@port) end}, restart: :permanent)
    ]
    opts = [strategy: :one_for_one, name: RTP_SSE.Supervisor]

    Util.JsonLog.clear_logs_on_startup()
    Supervisor.start_link(children, opts)
  end

end
