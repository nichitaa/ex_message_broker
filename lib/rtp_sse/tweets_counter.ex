defmodule RTP_SSE.TweetsCounter do
  import ShorterMaps
  use GenServer
  require Logger

  def start_link(opts) do
    ~M{routerPID} = parse_opts(opts)

    state = ~M{routerPID, counter: 0}
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Privates

  defp reset_counter_loop() do
    # Running in a separate process so it will not block
    counterPID = self()

    # Note! `self()` inside the spawn will be the inner process,
    # but we need the counter process
    spawn(
      fn ->
        Process.sleep(1000)
        GenServer.cast(counterPID, {:reset_counter})
      end
    )
  end

  ## Private

  defp parse_opts(opts) do
    routerPID = opts[:routerPID]
    ~M{routerPID}
  end

  ## Server callbacks

  @impl true
  def init(state) do
    reset_counter_loop()
    {:ok, state}
  end

  @impl true
  def handle_cast({:reset_counter}, state) do
    ~M{routerPID, counter} = state
    GenServer.cast(routerPID, {:autoscale, counter})
    reset_counter_loop()
    {:noreply, %{state | counter: 0}}
  end

  @impl true
  def handle_cast({:increment}, state) do
    {:noreply, %{state | counter: state.counter + 1}}
  end

end