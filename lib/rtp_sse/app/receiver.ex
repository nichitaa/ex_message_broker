defmodule App.Receiver do
  @sse_start_delay Application.fetch_env!(:rtp_sse, :sse_start_delay)

  import Destructure
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  ## Privates

  defp loop_receive(state) do
    d(%{counterPID, loggerWorkerPoolPID}) = state
    # Recursively wait for new events by defining the `receive` callback
    # and send the received `tweet.data` to the linked router process
    receive do
      tweet ->
        GenServer.cast(counterPID, {:increment})
        GenServer.cast(loggerWorkerPoolPID, {:route, tweet.data})
        loop_receive(state)
    end
  end

  ## Callbacks

  @impl true
  def init(state) do
    # will invoke handle_info(:start_receiver_worker) after 1 sec
    # this delay is required because other actors (like: Router)
    # are starting child workers with some delay too
    Process.send_after(self(), :start_receiver_worker, @sse_start_delay)
    {:ok, state}
  end

  @doc """
  Sets up new EventsourceEx that streams the events from `url` to the Receiver process
  """
  @impl true
  def handle_info(:start_receiver_worker, state) do
    EventsourceEx.new(state.url, stream_to: self())
    loop_receive(state)
    {:noreply, state}
  end


end