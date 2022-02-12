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

    # We need to handle 2 streams, so we need 2 LoggerRouters (aka worker pools)
    # that will handle workers and tweets for each stream particularly

    {:ok, router_1} =
      DynamicSupervisor.start_child(
        RTP_SSE.LoggerRouterDynamicSupervisor,
        {RTP_SSE.LoggerRouter, socket: socket}
      )

    {:ok, router_2} =
      DynamicSupervisor.start_child(
        RTP_SSE.LoggerRouterDynamicSupervisor,
        {RTP_SSE.LoggerRouter, socket: socket}
      )

    DynamicSupervisor.start_child(
      RTP_SSE.ReceiverWorkerDynamicSupervisor,
      {RTP_SSE.ReceiverWorker,
       socket: socket, url: "http://localhost:4000/tweets/1", routerPID: router_1}
    )

    DynamicSupervisor.start_child(
      RTP_SSE.ReceiverWorkerDynamicSupervisor,
      {RTP_SSE.ReceiverWorker,
       socket: socket, url: "http://localhost:4000/tweets/2", routerPID: router_2}
    )

    {:ok, "[Command] run :twitter\r\n"}
  end
end
