defmodule App.EventsBatcher do

  import Destructure
  use GenServer
  require Logger

  @batcher_flush_time Application.fetch_env!(:message_broker, :batcher_flush_time)

  def start_link(opts \\ []) do
    state = d(%{timer: nil})
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Callbacks

  @impl true
  def init(state) do
    # initiate a new timer
    timer = Process.send_after(self(), :flush_state, @batcher_flush_time)
    {:ok, %{state | timer: timer}}
  end

  @impl true
  def handle_info(:flush_state, state) do

    events = Agent.Events.get_and_reset()
    topics = Map.keys(events)

    Enum.each(
      topics,
      fn topic ->
        {:ok, prev_topic_logs} = Util.JSONLog.get(topic)
        current_topic_logs = events[topic]

        prev_subs_keys = Map.keys(prev_topic_logs)
        current_subs_keys = Map.keys(current_topic_logs)

        subs_keys = prev_subs_keys ++ current_subs_keys

        updated_topic_logs =
          Enum.reduce(
            subs_keys,
            prev_topic_logs,
            fn sub, acc ->
              prev_sub_events = Map.get(prev_topic_logs, sub, [])
              curr_sub_events =
                Map.get(current_topic_logs, sub, [])
                |> Enum.to_list()

              merged_events_list = prev_sub_events ++ curr_sub_events
              merged_events_pq = Util.JSONLog.list_to_pq(merged_events_list)
              merged_events_list = Util.JSONLog.pq_to_list(merged_events_pq)
              Map.put(acc, sub, merged_events_list)
            end
          )

        Util.JSONLog.update(topic, updated_topic_logs)
      end
    )

    timer = Process.send_after(self(), :flush_state, @batcher_flush_time)
    {:noreply, %{state | timer: timer}}
  end

end