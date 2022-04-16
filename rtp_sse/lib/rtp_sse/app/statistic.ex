defmodule App.Statistic do
  import Destructure
  use GenServer
  require Logger

  @mb_logger_stats_topic Application.fetch_env!(:rtp_sse, :mb_logger_stats_topic)
  @mb_users_stats_topic Application.fetch_env!(:rtp_sse, :mb_users_stats_topic)
  @mb_tweets_stats_topic Application.fetch_env!(:rtp_sse, :mb_tweets_stats_topic)

  def start_link(args, opts \\ []) do
    state = %{
      message_broker: args.message_broker,
      execution_times: [],
      bulk_tweets_time: [],
      bulk_users_time: [],
      ingested_tweets: 0,
      ingested_users: 0,
      crashes_nr: 0
    }
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Client API

  def add_execution_time(pid, time) do
    GenServer.cast(pid, {:add_execution_time, time})
  end

  ## Callbacks

  @impl true
  def init(state) do
    reset_stats_loop()
    {:ok, state}
  end

  @impl true
  def handle_cast({:reset_stats_loop}, state) do
    d(
      %{
        message_broker,
        execution_times,
        bulk_users_time,
        bulk_tweets_time,
        crashes_nr,
        ingested_users,
        ingested_tweets
      }
    ) = state

    if length(execution_times) > 0 do

      first = percentile(execution_times, 75)
      second = percentile(execution_times, 85)
      third = percentile(execution_times, 95)

      stats_info = "[StatisticWorker #{inspect(self())} -  message broker=#{
        inspect(message_broker)
      } - LoggerWorker execution time] Percentile stats 75%=#{first} | 85%=#{
        second
      } | 95%=#{third} [#{
        crashes_nr
      } CRASHES/5sec]"

      Logger.info(stats_info)
      :gen_tcp.send(message_broker, Utils.to_stats_topic_event(@mb_logger_stats_topic, stats_info))

    end

    if length(bulk_users_time) > 0 do

      first = percentile(bulk_users_time, 75)
      second = percentile(bulk_users_time, 85)
      third = percentile(bulk_users_time, 95)

      stats_info = "[StatisticWorker #{inspect(self())} - Bulk `users` insert stats] Execution time percentile 75%=#{
        first
      } | 85%=#{
        second
      } | 95%=#{third} [processed=#{inspect(ingested_users)}]"

      Logger.info(stats_info)
      :gen_tcp.send(message_broker, Utils.to_stats_topic_event(@mb_users_stats_topic, stats_info))

    end

    if length(bulk_tweets_time) > 0 do

      first = percentile(bulk_tweets_time, 75)
      second = percentile(bulk_tweets_time, 85)
      third = percentile(bulk_tweets_time, 95)

      stats_info = "[StatisticWorker #{inspect(self())} - Bulk `tweets` insert stats] Execution time percentile 75%=#{
        first
      } | 85%=#{
        second
      } | 95%=#{third} [processed=#{inspect(ingested_tweets)}]"

      Logger.info(stats_info)
      :gen_tcp.send(message_broker, Utils.to_stats_topic_event(@mb_tweets_stats_topic, stats_info))

    end

    reset_stats_loop()
    {
      :noreply,
      %{
        state |
        execution_times: [],
        bulk_tweets_time: [],
        bulk_users_time: [],
        ingested_tweets: 0,
        ingested_users: 0,
        crashes_nr: 0
      }
    }
  end

  # For LoggerWorker stats

  @impl true
  def handle_cast({:add_execution_time, time}, state) do
    {:noreply, %{state | execution_times: Enum.concat(state.execution_times, [time])}}
  end

  @impl true
  def handle_call({:add_worker_crash}, _from, state) do
    {:reply, nil, %{state | crashes_nr: state.crashes_nr + 1}}
  end

  # For DBService stats

  @impl true
  def handle_cast({:add_bulk_tweets_stats, time, amount}, state) do
    {
      :noreply,
      %{
        state |
        ingested_tweets: state.ingested_tweets + amount,
        bulk_tweets_time: Enum.concat(state.bulk_tweets_time, [time])
      }
    }
  end

  @impl true
  def handle_cast({:add_bulk_users_stats, time, amount}, state) do
    {
      :noreply,
      %{
        state |
        ingested_users: state.ingested_users + amount,
        bulk_users_time: Enum.concat(state.bulk_users_time, [time])
      }
    }
  end

  ## Privates

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
