defmodule MainSupervisor do

  use Supervisor
  import Destructure
  require Logger

  @streams_no Application.fetch_env!(:rtp_sse, :streams_no)
  @mb_host Application.fetch_env!(:rtp_sse, :mb_host)
  @mb_port Application.fetch_env!(:rtp_sse, :mb_port)
  @port Application.fetch_env!(:rtp_sse, :port)

  def start_link(init_arg) do
    name = String.to_atom("MainSupervisor_#{Kernel.inspect(init_arg.socket)}")
    Supervisor.start_link(__MODULE__, init_arg, name: name)
  end

  ## Callbacks

  def start_streams_supervisors(args, streams_supervisor_name, message_broker) do
    # because we have 2 SSE streams, we will start 2 similar "tree" structure
    Logger.info("[MainSupervisor] start_streams_supervisors #{streams_supervisor_name}")
    Enum.map(
      1..@streams_no,
      fn index ->
        {:ok, pid} = DynamicSupervisor.start_child(
          streams_supervisor_name,
          {StreamSupervisor, Map.merge(args, d(%{index, message_broker}))}
        )
      end
    )
  end

  @impl true
  def init(args) do

    # start a single Supervisor (will be used for supervising our streams Supervisors)
    streams_supervisor_name = String.to_atom("StreamsSupervisor_#{Kernel.inspect(args.socket)}")
    children = [
      {
        DynamicSupervisor,
        name: streams_supervisor_name,
        strategy: :one_for_one
      },
    ]

    case :gen_tcp.connect(@mb_host, @mb_port, [:binary, active: false, keepalive: true, reuseaddr: true,]) do
      {:ok, mb_socket} ->
        # await message broker connection response
        {:ok, response} = :gen_tcp.recv(mb_socket, 0, @port)
        Logger.info("Message Broker response=#{response}")

        spawn(
          fn ->
            Process.sleep(500)
            start_streams_supervisors(args, streams_supervisor_name, mb_socket)
          end
        )

      {:error, reason} ->
        Logger.info("Error: failed to connect to MessageBroker, reason: #{inspect(reason)}")
    end


    Supervisor.init(children, strategy: :one_for_one)
  end

end