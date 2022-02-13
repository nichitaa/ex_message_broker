defmodule RTP_SSE.Server do
  @moduledoc """
  A simple `TCP` server [docs](https://elixir-lang.org/getting-started/mix-otp/task-and-gen-tcp.html).
  It accepts connections on given port (8080 in my case) and spawns
  other processes (under Task.Supervisor `RTP_SSE.Server.TaskSupervisor`) that servers the requests (`commands`)
  """

  require Logger

  ## Client API

  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(
        port,
        [:binary, packet: :line, active: false, reuseaddr: true]
      )

    Logger.info("[Server] Accepting connections on PORT=#{port}")
    loop_acceptor(socket)
  end

  ## Private

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info("[Server] New client SOCKET=#{inspect(socket)}")

    {:ok, pid} =
      Task.Supervisor.start_child(RTP_SSE.Server.TaskSupervisor, fn -> serve(client) end)

    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(socket) do
    msg =
      with {:ok, data} <- read_line(socket),
           {:ok, command} <- RTP_SSE.Command.parse(data),
           do: RTP_SSE.Command.run(command, socket)

    write_line(socket, msg)
    serve(socket)
  end

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end

  defp write_line(socket, {:ok, text}) do
    :gen_tcp.send(socket, text)
  end

  defp write_line(socket, {:error, :unknown_command}) do
    :gen_tcp.send(socket, "UNKNOWN COMMAND\r\n")
  end

  defp write_line(_socket, {:error, :closed}) do
    exit(:shutdown)
  end

  defp write_line(socket, {:error, error}) do
    :gen_tcp.send(socket, "ERROR\r\n")
    exit(error)
  end
end
