defmodule Server do

  require Logger

  ## Client API

  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(
        port,
        [:binary, packet: :line, active: false, reuseaddr: true]
      )

    Logger.info("[Server #{inspect(self())}] Accepting connections on PORT=#{port}")
    loop_acceptor(socket)
  end

  ## Private

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info("[Server #{inspect(self())}] New client SOCKET=#{inspect(socket)}")
    :gen_tcp.send(client, "Type `twitter` to start processing SSE (from Twitter API)\r\n")

    {:ok, pid} =
      Task.Supervisor.start_child(Server.TaskSupervisor, fn -> serve(client) end)

    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(socket) do
    msg =
      with {:ok, data} <- read_line(socket),
           {:ok, command} <- Command.parse(data),
           do: Command.run(command, socket)

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
