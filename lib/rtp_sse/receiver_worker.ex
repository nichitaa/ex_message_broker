defmodule RTP_SSE.ReceiverWorker do
  @moduledoc """
  A basic receiver GenServer for the handling the incoming
  SSEs for a given socket (client), url (SSE endpoint) and router (Receiver will pass the
  event / tweet to it)
  """
  import Destructure
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    {:ok, counterPID} =
      DynamicSupervisor.start_child(
        RTP_SSE.TweetsCounterDynamicSupervisor,
        {RTP_SSE.TweetsCounter, d(%{routerPID: args.routerPID})}
      )

    state = Map.put(args, :counterPID, counterPID)
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Privates

  defp loop_receive(state) do
    d(%{socket, routerPID, counterPID}) = state
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
