defmodule MessageBroker do

  @moduledoc """
  # dev test
  pub tweets {"id":"1", "priority": 3, "msg":"tweet 1"}
  pub tweets {"id":"2", "priority": 4, "msg":"tweet 2"}
  pub tweets {"id":"3", "priority": 2, "msg":"tweet 3"}
  pub tweets {"id":"4", "priority": 5, "msg":"tweet 4"}

  pub users {"id":"1", "priority": 3, "msg":"users 1"}
  pub users {"id":"2", "priority": 4, "msg":"users 2"}
  pub users {"id":"3", "priority": 2, "msg":"users 3"}
  pub users {"id":"4", "priority": 5, "msg":"users 4"}
  """

  use Application
  require Logger

  @port Application.fetch_env!(:message_broker, :port)

  @impl true
  def start(_type, _args) do
    Logger.info("Starting MessageBroker")

    children = [
      # Agents (state)
      {Agent.Subscriptions, name: Agent.Subscriptions},
      {Agent.Events, name: Agent.Events},
      # Core
      {App.EventsBatcher, name: App.EventsBatcher},
      {App.Manager, name: App.Manager},
      # Utility
      {Util.JSONLog, name: Util.JSONLog},
      # Workers Pool
      {
        App.WorkerPool,
        %{
          name: App.WorkerPool,
          worker: Worker.Controller,
          workerArgs: [],
          pool_supervisor_name: WorkerPoolDynamicSupervisor
        }
      },
      {App.Counter, name: App.Counter},
      # WP Supervisor
      {DynamicSupervisor, name: WorkerPoolDynamicSupervisor, strategy: :one_for_one},
      # Server
      {Task.Supervisor, name: Server.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> Server.accept(@port) end}, restart: :permanent)
    ]
    opts = [strategy: :one_for_one, name: RTP_SSE.Supervisor]

    Util.JSONLog.clear_logs_on_startup()
    Supervisor.start_link(children, opts)
  end

end
