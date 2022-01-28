defmodule RTP_SSE.Command do
  require Logger

  ## Client API

  def parse(line) do
    case String.trim(line, "\r\n") do
      "twitter" -> {:ok, {:twitter}}
      _ -> {:error, :unknown_command}
    end
  end

  def run(command, socket)

  def run({:twitter}, socket) do
    Logger.info("[Command] run :twitter - socket - #{inspect(socket)}")

    {:ok, pid} =
      DynamicSupervisor.start_child(
        RTP_SSE.LoggerRouterDynamicSupervisor,
        {RTP_SSE.LoggerRouter, socket: socket}
      )

    DynamicSupervisor.start_child(
      RTP_SSE.ReceiverWorkerDynamicSupervisor,
      {RTP_SSE.ReceiverWorker,
       socket: socket, url: "http://localhost:4000/tweets/2", routerPID: pid}
    )

    {:ok, "[Command] run :twitter\r\n"}
  end
end
