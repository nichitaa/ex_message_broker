defmodule SubClient do
  use GenServer
  require Logger

  @mb_subscribe_command Application.fetch_env!(:subscriber, :mb_subscribe_command)
  @mb_acknowledge_command Application.fetch_env!(:subscriber, :mb_acknowledge_command)
  @mb_port Application.fetch_env!(:subscriber, :mb_port)
  @mb_host Application.fetch_env!(:subscriber, :mb_host)
  @mb_topic Application.fetch_env!(:subscriber, :mb_topic)


  def start_link(opts \\ []) do
    Logger.info("SubClient start_link opts=#{inspect opts}")
    topic = opts[:topic]
    Logger.info("topic=#{topic}")
    state = %{mb_socket: nil, topic: topic}
    GenServer.start_link(__MODULE__, state, opts)
  end

  @impl true
  def init(state) do
    Logger.info("SubClient init")

    conn_opts = [:binary, active: false, keepalive: true, reuseaddr: true, packet: :line]
    {:ok, mb_socket} =
      case :gen_tcp.connect(@mb_host, @mb_port, conn_opts) do
        {:ok, mb_socket} ->
          {:ok, mb_socket}
        {:error, reason} ->
          Logger.info("Error: failed to connect to MB, reason: #{inspect(reason)}")
      end

    send_sub(mb_socket, state.topic)

    {:ok, pid} = Task.Supervisor.start_child(SubClient.TaskSupervisor, fn -> recv_loop(mb_socket, state.topic) end)
    :ok = :gen_tcp.controlling_process(mb_socket, pid)

    Logger.info("SubClient connected to MB socket=#{inspect mb_socket}")
    {:ok, %{state | mb_socket: mb_socket}}
  end

  def recv_loop(sock, topic) do
    case :gen_tcp.recv(sock, 0) do
      {:ok, line} ->
        case Poison.decode(line) do
          {:ok, json} ->
            Logger.info("msg=#{inspect json["msg"]}")
            Process.sleep(50)
            send_ack(sock, topic, json["id"])
          other ->
            parsed =
              String.trim(line, "\r\n")
              |> String.split(" ", parts: 2)
            case parsed do
              ["no_event_error:", ev_id] ->
                send_ack(sock, topic, ev_id)
              x ->
                Logger.info("recv=#{inspect String.trim(line, "\r\n")}")
            end
        end

        {:ok, pid} = Task.Supervisor.start_child(SubClient.TaskSupervisor, fn -> recv_loop(sock, topic) end)
        :ok = :gen_tcp.controlling_process(sock, pid)

        # recv_loop(sock, topic)
      {:error, reason} -> Logger.info("error: recv reason=#{inspect(reason)}")
    end
  end

  defp send_ack(mb_sock, topic, ev_id) do
    cmd = @mb_acknowledge_command <> " " <> topic <> " " <> ev_id <> "\r\n"
    Logger.info("cmd=#{inspect cmd}")
    :gen_tcp.send(mb_sock, cmd)
  end

  defp send_sub(mb_sock, topic) do
    cmd = @mb_subscribe_command <> " " <> topic <> "\r\n"
    :gen_tcp.send(mb_sock, cmd)
  end

end