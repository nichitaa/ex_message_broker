defmodule RTP_SSE.ReceiverWorker do
  @moduledoc """
  A basic receiver GenServer for the handling the incoming
  SSEs for a given socket (client), url (SSE endpoint) and router (Receiver will pass the
  event / tweet to it)
  """

  import ShorterMaps
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    ~M{socket, url, routerPID} = parse_opts(args)

    Logger.info(
      "[ReceiverWorker] start_link SOCKET=#{inspect(socket)}, routerPID=#{inspect(routerPID)}, url=#{url}"
    )

    {:ok, counterPID} =
      DynamicSupervisor.start_child(
        RTP_SSE.TweetsCounterDynamicSupervisor,
        {RTP_SSE.TweetsCounter, routerPID: routerPID}
      )

    GenServer.start_link(__MODULE__, ~M{socket, url, routerPID, counterPID}, opts)
  end

  ## Private

  defp parse_opts(opts) do
    socket = opts[:socket]
    url = opts[:url]
    routerPID = opts[:routerPID]
    ~M{socket, url, routerPID}
  end

  defp loop_receive(state) do
    ~M{socket, routerPID, counterPID} = state
    # Recursively wait for new events by defining the `receive` callback
    # and send the received `tweet.data` to the linked router process
    receive do
      tweet ->
        GenServer.cast(counterPID, {:increment})
        GenServer.cast(routerPID, {:route, tweet.data})
        loop_receive(state)
    end
  end

  ## Callbacks

  @impl true
  def init(state) do
    # will invoke handle_info(:start_receiver_worker) after 200 ms
    Process.send_after(self(), :start_receiver_worker, 200)
    {:ok, state}
  end

  @doc """
  Sets up new EventsourceEx that streams the events from `url` to the Receiver process
  """
  @impl true
  def handle_info(:start_receiver_worker, state) do
    Logger.info("[ReceiverWorker #{inspect(self())}] :start_receiver_worker")
    EventsourceEx.new(state.url, stream_to: self())
    loop_receive(state)
    {:noreply, state}
  end
end
