defmodule RTP_SSE.Command do
  @moduledoc """
  Utility like module for our `RTP_SSE.Server` commands.
  Contains the definition for each command, knows how to parse and run it.
  """

  require Logger

  ## Client API

  def parse(line) do
    case String.trim(line, "\r\n") do
      "twitter" -> {:ok, {:twitter}}
      _ -> {:error, :unknown_command}
    end
  end

  @doc """
  Runs the given command.
  Available commands are:
  
      twitter
  """
  def run(command, socket)

  @doc """
  `twitter` command handler.
  
  First of all it gets all of the available LoggerRouters (worker routers) for the given socket (client).
  If there are any, that means that this socket previously instantiated the processes for the `twitter` command
  and we can use the same LoggerRouter and LoggerWorker again, but we still need to start new Receivers processes
  for the SSEs.
  
  If it is the first `twitter` command, then there are not linked LoggerRouters to the socket and we need to
  create 2 ReceiverWorkers (because we have 2 SSEs on 2 different endpoints) and for each Receiver we create a
  LoggerRouter that internally supervises and spins up the LoggerWorkers (workers).
  """
  def run({:twitter}, socket) do
    Logger.info("[Command] :twitter for SOCKET=#{inspect(socket)}")

    # get all active LoggerRouters
    logger_routers = DynamicSupervisor.which_children(RTP_SSE.LoggerRouterDynamicSupervisor)

    # get LoggerRouters only for this specific socket (client)
    routers_for_socket =
      Enum.filter(
        logger_routers,
        fn router ->
          routerPID = elem(router, 1)
          # will return a boolean
          GenServer.call(routerPID, {:is_router_for_socket, socket})
        end
      )
      |> Enum.map(fn x ->
        # get only the PID from tuple
        elem(x, 1)
      end)

    # we found active LoggerRouters for this socket, no need to create new LoggerRouters and workers
    if length(routers_for_socket) > 0 do
      Logger.info(
        "[Command] Duplicate :twitter for SOCKET=#{inspect(socket)}, will use same workers"
      )

      # start a new SSE Receiver for already existing routers and workers
      routers_for_socket
      |> Enum.with_index()
      |> Enum.each(fn {routerPID, index} ->
        DynamicSupervisor.start_child(
          RTP_SSE.ReceiverWorkerDynamicSupervisor,
          {
            RTP_SSE.ReceiverWorker,
            # endpoints are `/1` and `/2`
            socket: socket, url: "http://localhost:4000/tweets/#{index + 1}", routerPID: routerPID
          }
        )
      end)
    else
      # there are not LoggerRouter for the `twitter` command for this client, start all required processes
      # start 2 new LoggerRouter ( 1..2 map because of the endpoints)
      Logger.info(
        "[Command] :twitter for SOCKET=#{inspect(socket)}, will start new LoggerRouter processes"
      )

      routerPIDs =
        Enum.map(
          1..2,
          fn i ->
            {:ok, routerPID} =
              DynamicSupervisor.start_child(
                RTP_SSE.LoggerRouterDynamicSupervisor,
                {RTP_SSE.LoggerRouter, socket: socket}
              )

            {routerPID, i}
          end
        )

      # start 2 new Receivers for handing the incoming SSE for the given enpoints
      Enum.map(
        routerPIDs,
        fn {pid, i} ->
          DynamicSupervisor.start_child(
            RTP_SSE.ReceiverWorkerDynamicSupervisor,
            {
              RTP_SSE.ReceiverWorker,
              socket: socket, url: "http://localhost:4000/tweets/#{i}", routerPID: pid
            }
          )
        end
      )
    end

    {:ok, "[Command] run :twitter\r\n"}
  end
end
