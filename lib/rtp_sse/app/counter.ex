defmodule App.Counter do
  import Destructure
  use GenServer
  require Logger

  @autoscaler_time_frame Application.fetch_env!(:rtp_sse, :autoscaler_time_frame)
  @enable_autoscaler Application.fetch_env!(:rtp_sse, :enable_autoscaler)

  def start_link(args, opts \\ []) do
    state = Map.put(args, :counter, 0)
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
    d(%{workerPoolPIDs, counter}) = state
    # Iterate over worker pools and autoscale them
    Enum.map(
      workerPoolPIDs,
      fn pid ->
        if (@enable_autoscaler == true) do
          GenServer.cast(pid, {:autoscale, counter})
        end
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
