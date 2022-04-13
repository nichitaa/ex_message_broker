defmodule Server do

  require Logger

  ## Client API

  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(
        port,
        [:binary, packet: :line, active: false, reuseaddr: true]
      )

    Logger.info("[MB-Server #{inspect(self())}] Accepting connections on PORT=#{port}")
    loop_acceptor(socket)
  end

  ## Private

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info("[MB-Server #{inspect(self())}] New client SOCKET=#{inspect(socket)}, client=#{inspect(client)}")

    {:ok, pid} =
      Task.Supervisor.start_child(Server.TaskSupervisor, fn -> serve(client) end)

    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(socket) do
    with {:ok, data} <- read_line(socket),
         do: send_response_to_producer(socket, {:ok, "response from MB\r\n"})
    serve(socket)
  end

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end

  defp send_response_to_producer(socket, {:ok, text}) do
    case :gen_tcp.connect('localhost', 8080, [:binary, active: true]) do
      {:ok, prod_socket} ->
        Logger.info("MB-Server producer client socket=#{inspect(prod_socket)}")
        ok = :gen_tcp.send(prod_socket, text)
      {:error, reason} ->
        Logger.info("error on sending a response to producer")
    end
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
