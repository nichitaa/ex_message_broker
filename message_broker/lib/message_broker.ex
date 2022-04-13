defmodule MessageBroker do
  use Application
  require Logger

  @port Application.fetch_env!(:message_broker, :port)

  @impl true
  def start(_type, _args) do
    Logger.info("Starting MessageBroker")

    children = [
      # Server
      {Task.Supervisor, name: Server.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> Server.accept(@port) end}, restart: :permanent)
    ]
    opts = [strategy: :one_for_one, name: RTP_SSE.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def run_test_snippets() do
    ["PUBLISH", "tweets", "{\"name\":\"Devin", "Torres\",\"age\":27}"]
  end

end
