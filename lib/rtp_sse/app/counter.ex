defmodule App.Counter do
  import Destructure
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    Logger.info("Counter start_link: #{inspect(args)}")
    state = Map.put(args, :counter, 0)
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Privates

  defp reset_counter_loop() do
    # Running in a separate process so it will not block
    counterPID = self()

    # Note! `self()` inside the spawn will be the inner process,
    # but we need the counter process
    spawn(fn ->
      Process.sleep(1000)
      GenServer.cast(counterPID, {:reset_counter})
    end)
  end

  ## Callbacks

  @impl true
  def init(state) do
     reset_counter_loop()
    {:ok, state}
  end

  @impl true
  def handle_cast({:reset_counter}, state) do
    d(%{workerPoolPIDs, counter}) = state
    # Iterate over worker pools and autoscale them
    Enum.map(
      workerPoolPIDs,
      fn pid ->
#        nil
         GenServer.cast(pid, {:autoscale, counter})
      end
    )
    reset_counter_loop()
    {:noreply, %{state | counter: 0}}
  end

  @impl true
  def handle_cast({:increment}, state) do
    {:noreply, %{state | counter: state.counter + 1}}
  end
end
