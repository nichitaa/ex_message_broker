defmodule RTP_SSE do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("[Application] start")

    children = [
      {Task.Supervisor, name: RTP_SSE.Server.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> RTP_SSE.Server.accept(8080) end}, restart: :permanent)
    ]

    opts = [strategy: :one_for_one, name: RTP_SSE.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
