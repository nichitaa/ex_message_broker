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

  def notify(subscriber, message) do
    :gen_tcp.send(subscriber, message <> "\r\n")
  end

  ## Private

  defp loop_acceptor(socket) do
    {:ok, subscriber} = :gen_tcp.accept(socket)
    Logger.info("[MB-Server #{inspect(self())}] NEW subscriber=#{inspect(subscriber)}")
    :gen_tcp.send(subscriber, "Successfully connected to message_broker\r\n")

    {:ok, pid} = Task.Supervisor.start_child(Server.TaskSupervisor, fn -> serve(subscriber) end)

    :ok = :gen_tcp.controlling_process(subscriber, pid)
    loop_acceptor(socket)
  end

  defp serve(subscriber_socket) do
    with {:ok, data} <- read_line(subscriber_socket),
         {:ok, command} <- Command.parse(data),
         do: Command.run(command, subscriber_socket)
    serve(subscriber_socket)
  end

  defp read_line(subscriber_socket) do
    :gen_tcp.recv(subscriber_socket, 0)
  end

  defp write_line(_socket, {:error, :closed}) do
    exit(:shutdown)
  end

end
