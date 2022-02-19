defmodule RTP_SSE.TweetsCounter do
  use GenServer
  require Logger

  ## Client API

  def start_link(opts) do
    {routerPID} = parse_opts(opts)
    state = %{routerPID: routerPID, counter: 0}
    GenServer.start_link(__MODULE__, state, opts)
  end

  def reset_counter_loop() do
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
    {routerPID}
  end

  ## Server callbacks

  @impl true
  def init(state) do
    reset_counter_loop()
    {:ok, state}
  end

  @impl true
  def handle_cast({:reset_counter}, state) do
    GenServer.cast(state.routerPID, {:autoscale, state.counter})
    reset_counter_loop()
    {:noreply, %{routerPID: state.routerPID, counter: 0}}
  end

  @impl true
  def handle_cast({:increment}, state) do
    {:noreply, %{routerPID: state.routerPID, counter: state.counter + 1}}
  end

end