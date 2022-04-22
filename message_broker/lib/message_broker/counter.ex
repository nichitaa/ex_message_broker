defmodule Counter do
  import Destructure
  use GenServer
  require Logger

  @autoscaler_time_frame 1000
  @enable_autoscaler true

  def start_link(opts \\ []) do
    state = Map.put(%{}, :counter, 0)
    GenServer.start_link(__MODULE__, state, opts)
  end

  def increment() do
    GenServer.cast(__MODULE__, {:increment})
  end

  ## Privates

  defp reset_counter_loop() do
    counterPID = self()
    spawn(
      fn ->
        Process.sleep(@autoscaler_time_frame)
        GenServer.cast(counterPID, {:reset_counter})
      end
    )
  end

  ## Callbacks

  @impl true
  def init(state) do
    reset_counter_loop()
    {:ok, state}
  end

  @impl true
  def handle_cast({:reset_counter}, state) do
    d(%{counter}) = state
    if (@enable_autoscaler == true) do
      WorkerPool.autoscale(counter)
    end
    reset_counter_loop()
    {:noreply, %{state | counter: 0}}
  end

  @impl true
  def handle_cast({:increment}, state) do
    {:noreply, %{state | counter: state.counter + 1}}
  end
end
