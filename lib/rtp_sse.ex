defmodule RTP_SSE do
  @moduledoc """
  iex -S mix
  :observer.start()

  telnet localhost 8080
  """
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("[Application] start")

    children = [
      {DynamicSupervisor, name: RTP_SSE.LoggerWorkerDynamicSupervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: RTP_SSE.LoggerRouterDynamicSupervisor, strategy: :one_for_one},
      # Dynamic supervisor for the ReceiverWorker (handles sse for subscribers)
      {DynamicSupervisor, name: RTP_SSE.ReceiverWorkerDynamicSupervisor, strategy: :one_for_one},
      # Server
      {Task.Supervisor, name: RTP_SSE.Server.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> RTP_SSE.Server.accept(8080) end}, restart: :permanent)
    ]

    opts = [strategy: :one_for_one, name: RTP_SSE.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
