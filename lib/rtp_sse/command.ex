defmodule RTP_SSE.Command do
  @moduledoc """
  Utility like module for our `RTP_SSE.Server` commands.
  Contains the definition for each command, knows how to parse and run it.
  """
  import Destructure
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
      # get only the PID from tuple
      |> Enum.map(fn x -> elem(x, 1) end)

    # we found active LoggerRouters for this socket, no need to create new LoggerRouters and workers
    if length(routers_for_socket) > 0 do
      Logger.info(
        "[Command] Duplicate :twitter for SOCKET=#{inspect(socket)}, will use same workers"
      )

      # start a new SSE Receiver for already existing routers and workers
      routers_for_socket
      |> Enum.with_index()
      |> Enum.each(
           fn {routerPID, index} ->
             DynamicSupervisor.start_child(
               RTP_SSE.ReceiverWorkerDynamicSupervisor,
               {
                 RTP_SSE.ReceiverWorker,
                 # endpoints are `/1` and `/2`
                 d(%{socket, routerPID, url: "http://localhost:4000/tweets/#{index + 1}"}),
               }
             )
           end
         )
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
                {RTP_SSE.LoggerRouter, d(%{socket})}
              )

            {routerPID, i}
          end
        )

      # start 2 new Receivers for handing the incoming SSE for the given endpoints
      Enum.map(
        routerPIDs,
        fn {routerPID, index} ->
          DynamicSupervisor.start_child(
            RTP_SSE.ReceiverWorkerDynamicSupervisor,
            {
              RTP_SSE.ReceiverWorker,
              d(%{socket, routerPID, url: "http://localhost:4000/tweets/#{index}"}),
            }
          )
        end
      )
    end

    {:ok, "[Command] run :twitter\r\n"}
  end
end
