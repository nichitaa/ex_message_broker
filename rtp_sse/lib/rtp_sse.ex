defmodule RTP_SSE do
  use Application
  require Logger

  @port Application.fetch_env!(:rtp_sse, :port)

  @impl true
  def start(_type, _args) do
    Logger.info("Starting RTP_SSE")

    children = [
      # Supervisor tree structure will start under it
      {DynamicSupervisor, name: MainDynamicSupervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: CommandSupervisor, strategy: :one_for_one},

      # Server
      {Task.Supervisor, name: Server.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> Server.accept(@port) end}, restart: :permanent)
    ]
    opts = [strategy: :one_for_one, name: RTP_SSE.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
