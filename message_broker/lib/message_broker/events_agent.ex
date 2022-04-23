defmodule EventsAgent do
  import Destructure
  require Logger
  use Agent

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def get_subscribers_to_notify(topic) do
    topic_subscribers = SubscriptionsAgent.get_topic_subscribers(topic)
    events = Agent.get(__MODULE__, fn x -> Map.get(x, topic, %{}) end)
    subscribers_to_notify = Enum.filter(
      topic_subscribers,
      fn subscriber ->
        subscriber_events = events[Kernel.inspect(subscriber)]
#        {:ok, subscriber_logs} = Util.JsonLog.get(topic)
#        subscriber_logs = subscriber_logs[Kernel.inspect(subscriber)]

        can_send = (subscriber_events == nil or Enum.count(subscriber_events) == 0)
        # and (subscriber_logs == nil or length(subscriber_logs) == 0)
        can_send
      end
    )
    subscribers_to_notify
  end

  def publish_event(topic, event) do
    topic_subscribers = SubscriptionsAgent.get_topic_subscribers(topic)
    topic_events = Agent.get(__MODULE__, fn x -> Map.get(x, topic, %{}) end)
    Agent.update(
      __MODULE__,
      fn events ->
        updated_topic_events = Enum.reduce(
          # iterate thru topic subscribers
          topic_subscribers,
          topic_events,
          fn subscriber, acc_logs ->
            # new log event
            event_log = Util.JsonLog.event_to_log(event)
            Map.update(
              acc_logs,
              # Port -> String (this is the log key)
              Kernel.inspect(subscriber),
              # default: a PQ of one event
              Util.JsonLog.list_to_pq([event_log]),
              fn prev ->
                # add to priority queue
                PSQ.put(prev, event_log)
              end
            )
          end
        )
        Map.put(events, topic, updated_topic_events)
      end
    )
  end

  def get_subscriber_next_message(topic, subscriber) do
    subscriber = Kernel.inspect(subscriber)
    subscriber_events_pq = Agent.get(
      __MODULE__,
      fn all_events ->
        Kernel.get_in(all_events, [topic, subscriber])
      end
    )
    if subscriber_events_pq != nil and Enum.count(subscriber_events_pq) > 0 do
      {next_event, _} = PSQ.pop(subscriber_events_pq)
      {:ok, next_event}
    else
      # get from logs then
      {:ok, topic_logs} = Util.JsonLog.get(topic)
      subscriber_logs = topic_logs[subscriber]
      if subscriber_logs != nil and length(subscriber_logs) > 0 do
        {next_event, _} = List.pop_at(subscriber_logs, 0)
        {:ok, next_event}
      else
        {:err, "no available message"}
      end
    end
  end


  def acknowledge_session_event(topic, subscriber, event_id) do
    subscriber = Kernel.inspect(subscriber)
    subscriber_events_pq = Agent.get(
      __MODULE__,
      fn all_events ->
        Kernel.get_in(all_events, [topic, subscriber])
      end
    )
    if subscriber_events_pq != nil and Enum.count(subscriber_events_pq) > 0 do
      ack_event = PSQ.get(subscriber_events_pq, event_id)

      if ack_event != nil do
        updated_pq = PSQ.delete(subscriber_events_pq, event_id)

        # state update
        Agent.update(
          __MODULE__,
          fn all_events ->
            Kernel.put_in(
              all_events,
              [topic, subscriber],
              updated_pq
            )
          end
        )
        {:ok, "acknowledged from current session"}
      else
        {:err, "error: no event with id=#{event_id} in session"}
      end
    else
      {:err, "error: no session events"}
    end
  end

  def get_and_reset() do
    Agent.get_and_update(__MODULE__, fn x -> {x, %{}} end)
  end

  def stats() do
    Agent.get(
      __MODULE__,
      fn events ->
        topics = Map.keys(events)
        Logger.info("topics=#{inspect(topics)}")
        Enum.each(
          topics,
          fn x ->
            subs = Map.keys(events[x])
            Logger.info("topic=#{inspect(x)} subs=#{inspect(subs)}")
            Enum.each(
              subs,
              fn s ->
                len = length(events[x][s])
                Logger.info("sub=#{inspect(s)} topic=#{inspect(x)} len=#{inspect(len)}")
              end
            )
          end
        )
      end
    )
  end
end