defmodule RTP_SSE.StatisticWorker do

  import Destructure
  use GenServer
  require Logger

  ## Server callbacks

  @impl true
  def start_link(_args, opts \\ []) do
    state = %{execution_times: [], crashes_nr: 0}
    GenServer.start_link(__MODULE__, state, opts)
  end

  @impl true
  def init(state) do
    reset_stats_loop()
    {:ok, state}
  end

  @impl true
  def handle_cast({:reset_stats_loop}, state) do
    d(%{execution_times, crashes_nr}) = state

    if length(execution_times) > 0 do
      first = percentile(execution_times, 75)
      second = percentile(execution_times, 85)
      third = percentile(execution_times, 95)
      Logger.info(
        "[StatisticWorker #{inspect(self())}] Percentile stats 75%=#{first} | 85%=#{second} | 95%=#{third} [#{
          crashes_nr
        } CRASHES/5sec]"
      )
    end
    reset_stats_loop()
    {:noreply, %{execution_times: [], crashes_nr: 0}}
  end

  @impl true
  def handle_cast({:add_execution_time, time}, state) do
    {:noreply, %{state | execution_times: Enum.concat(state.execution_times, [time])}}
  end

  @impl true
  def handle_call({:add_worker_crash}, _from, state) do
    {:reply, nil, %{state | crashes_nr: state.crashes_nr + 1}}
  end

  ## Private

  defp reset_stats_loop() do
    pid = self()
    spawn(
      fn ->
        Process.sleep(5000)
        GenServer.cast(pid, {:reset_stats_loop})
      end
    )
  end

  @doc """
    Compute percentile for a given list and percentile value respectively
    Reference: https://github.com/msharp/elixir-statistics/blob/897851ffd947e549181e49fcc21fb8b58f106293/lib/statistics.ex#L195
  """
  defp percentile([], _), do: nil
  defp percentile([x], _), do: x

  defp percentile(list, n) when is_list(list) and is_number(n) do
    s = Enum.sort(list)
    r = n / 100.0 * (length(list) - 1)
    f = :erlang.trunc(r)
    lower = Enum.at(s, f)
    upper = Enum.at(s, f + 1)
    res = lower + (upper - lower) * (r - f)
    Float.ceil(res, 2)
  end

end