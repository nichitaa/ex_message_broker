defmodule MainSupervisor do

  use Supervisor
  import Destructure
  require Logger

  @streams_no Application.fetch_env!(:rtp_sse, :streams_no)

  def start_link(init_arg) do
    name = String.to_atom("MainSupervisor_#{Kernel.inspect(init_arg.socket)}")
    Supervisor.start_link(__MODULE__, init_arg, name: name)
  end

  ## Callbacks

  def start_streams_supervisors(args, streams_supervisor_name) do
    # because we have 2 SSE streams, we will start 2 similar "tree" structure
    Logger.info("[MainSupervisor] start_streams_supervisors #{streams_supervisor_name}")
    Enum.map(
      1..@streams_no,
      fn index ->
        {:ok, pid} = DynamicSupervisor.start_child(
          streams_supervisor_name,
          {StreamSupervisor, Map.merge(args, d(%{index}))}
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

    spawn(
      fn ->
        Process.sleep(500)
        start_streams_supervisors(args, streams_supervisor_name)
      end
    )
    Supervisor.init(children, strategy: :one_for_one)
  end

end