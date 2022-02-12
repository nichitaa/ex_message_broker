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

    # get all routers
    logger_routers = DynamicSupervisor.which_children(RTP_SSE.LoggerRouterDynamicSupervisor)

    routers_for_socket =
      Enum.filter(logger_routers, fn router ->
        routerPID = elem(router, 1)
        # return a boolean
        GenServer.call(routerPID, {:is_router_for_socket, socket})
      end)
      |> Enum.map(fn x ->
        # get only the PID from tuple
        elem(x, 1)
      end)

    if length(routers_for_socket) > 0 do
      # start a new sse receiver for already existing routers and workers
      routers_for_socket
      |> Enum.with_index()
      |> Enum.each(fn {routerPID, index} ->
        DynamicSupervisor.start_child(
          RTP_SSE.ReceiverWorkerDynamicSupervisor,
          {RTP_SSE.ReceiverWorker,
           socket: socket, url: "http://localhost:4000/tweets/#{index + 1}", routerPID: routerPID}
        )
      end)
    else
      # first `twitter` command for client
      # start new routers and receivers for both endpoints (`/tweets/1` and `tweets/2`)
      routerPIDs =
        Enum.map(1..2, fn i ->
          {:ok, routerPID} =
            DynamicSupervisor.start_child(
              RTP_SSE.LoggerRouterDynamicSupervisor,
              {RTP_SSE.LoggerRouter, socket: socket}
            )

          {routerPID, i}
        end)

      Enum.map(routerPIDs, fn {pid, i} ->
        Logger.info("PID AND I: #{inspect(pid)} #{inspect(i)}")

        DynamicSupervisor.start_child(
          RTP_SSE.ReceiverWorkerDynamicSupervisor,
          {RTP_SSE.ReceiverWorker,
           socket: socket, url: "http://localhost:4000/tweets/#{i}", routerPID: pid}
        )
      end)
    end

    {:ok, "[Command] run :twitter\r\n"}
  end
end
