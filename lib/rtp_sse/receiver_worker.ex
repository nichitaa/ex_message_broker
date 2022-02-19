defmodule RTP_SSE.ReceiverWorker do
  @moduledoc """
  A basic receiver GenServer for the handling the incoming
  SSEs for a given socket (client), url (SSE endpoint) and router (Receiver will pass the
  event / tweet to it)
  """

  use GenServer
  require Logger

  ## Client API

  def start_link(opts) do
    {socket, url, routerPID} = parse_opts(opts)

    Logger.info(
      "[ReceiverWorker] start_link SOCKET=#{inspect(socket)}, routerPID=#{inspect(routerPID)}, url=#{url}"
    )

    {:ok, counterPID} =
      DynamicSupervisor.start_child(
        RTP_SSE.TweetsCounterDynamicSupervisor,
        {RTP_SSE.TweetsCounter, routerPID: routerPID}
      )

    state = %{
      socket: socket,
      url: url,
      routerPID: routerPID,
      counterPID: counterPID
    }

    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Private

  defp parse_opts(opts) do
    socket = opts[:socket]
    url = opts[:url]
    routerPID = opts[:routerPID]
    {socket, url, routerPID}
  end

  defp loop_receive(socket, routerPID, counterPID) do
    # Recursively wait for new events by defining the `receive` callback
    # and send the received `tweet.data` to the linked router process
    receive do
      tweet ->
        GenServer.cast(counterPID, {:increment})
        GenServer.cast(routerPID, {:route, tweet.data})
        loop_receive(socket, routerPID, counterPID)
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
    Logger.info("[ReceiverWorker] :start_receiver_worker")
    EventsourceEx.new(state.url, stream_to: self())
    loop_receive(state.socket, state.routerPID, state.counterPID)
    {:noreply, state}
  end
end
