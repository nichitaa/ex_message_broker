defmodule EventsBatcher do

  import Destructure
  use GenServer
  require Logger

  @batcher_flush_time 2000

  def start_link(opts \\ []) do
    state = d(%{timer: nil})
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Client API

  ## Privates

  ## Callbacks

  @impl true
  def init(state) do
    # initiate a new timer
    timer = Process.send_after(self(), :flush_state, @batcher_flush_time)
    {:ok, %{state | timer: timer}}
  end

  @impl true
  def handle_info(:flush_state, state) do

    events = EventsAgent.get_and_reset()
    # Logger.info("events=#{inspect(events)}")
    topics = Map.keys(events)
    # Logger.info("topics=#{inspect(topics)}")

    Enum.each(
      topics,
      fn topic ->
        {:ok, prev_topic_logs} = Util.JsonLog.get(topic)
        current_topic_logs = events[topic]
        # Logger.info("prev_topic_logs=#{inspect(prev_topic_logs)} = current_topic_logs=#{inspect(current_topic_logs)}")

        merged_logs =
          if length(Map.keys(prev_topic_logs)) == 0 do
            subs = Map.keys(current_topic_logs)
            converted =
              Enum.reduce(
                subs,
                current_topic_logs,
                fn sub, acc ->
                  Map.update!(
                    acc,
                    sub,
                    fn pq -> Util.JsonLog.pq_to_list(pq) end
                  )
                end
              )
            converted
          else
            Map.merge(
              prev_topic_logs,
              current_topic_logs,
              fn key, la, lb ->
                # Logger.info("key=#{inspect(key)} la=#{inspect(la)} lb=#{inspect(lb)}")
                if la == nil do
                  Util.JsonLog.pq_to_list(lb)
                end
                if lb == nil do
                  la
                end
                if la != nil and lb != nil do
                  # Logger.info("nothing is nil")
                  lb = Util.JsonLog.pq_to_list(lb)
                  list_merged = la ++ lb
                  list_merged_pq = Util.JsonLog.list_to_pq(list_merged)
                  Util.JsonLog.pq_to_list(list_merged_pq)
                end
              end
            )
          end
        Logger.info("topic=#{inspect(topic)} merged_logs=#{inspect(Map.keys(merged_logs))}")
        Util.JsonLog.update(topic, merged_logs)
      end
    )


    timer = Process.send_after(self(), :flush_state, @batcher_flush_time)
    {:noreply, %{state | timer: timer}}
  end

end