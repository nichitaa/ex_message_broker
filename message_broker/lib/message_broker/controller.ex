defmodule Controller do

  import Destructure
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:work, command}, state) do
    GenServer.cast(self(), command)
    {:noreply, state}
  end

  def send_next_event(topic, subscriber) do
    case EventsAgent.get_subscriber_next_message(topic, subscriber) do
      {:ok, next_event} ->
        {:ok, encode_event} = Poison.encode(next_event)
        msg = Util.JsonLog.event_to_msg(topic, encode_event)
        Server.notify(subscriber, msg)
      {:err, err_msg} ->
        Server.notify(subscriber, err_msg)
    end
  end

  @impl true
  def handle_cast({:acknowledge, topic, subscriber, event_id}, state) do

    Util.JsonLog.check_log_file(topic)
    # Server.notify(subscriber, "just received ack ev_id=#{inspect(event_id)}")
    case SubscriptionsAgent.is_topic_subscriber(topic, subscriber) do
      true ->
        # try acknowledge from session (2sec buffer)
        case EventsAgent.acknowledge_session_event(topic, subscriber, event_id) do
          {:ok, success_msg} ->
            Server.notify(subscriber, success_msg)
            send_next_event(topic, subscriber)
          {:err, err_msg} ->
            # check logs then
            # Server.notify(subscriber, err_msg)
            {:ok, topic_logs} = Util.JsonLog.get(topic)
            subscriber_logs = topic_logs[Kernel.inspect(subscriber)]
            if subscriber_logs != nil and length(subscriber_logs) > 0 do
              pq = Util.JsonLog.list_to_pq(subscriber_logs)
              ack_log = PSQ.get(pq, event_id)
              if ack_log != nil do
                pq = PSQ.delete(pq, event_id)
                Server.notify(subscriber, "acknowledged from logs ev_id=#{event_id}")
                logs_list = Util.JsonLog.pq_to_list(pq)
                updated_topic_logs = Map.put(topic_logs, Kernel.inspect(subscriber), logs_list)
                Util.JsonLog.update(topic, updated_topic_logs)
                send_next_event(topic, subscriber)
              else
                Server.notify(subscriber, "error: no event with id=#{event_id} in logs")
              end
            else
              Server.notify(subscriber, "error: no subscriber logs")
            end
        end
      false ->
        Server.notify(subscriber, "error: not a topic #{topic} subscriber")
    end

    {:noreply, state}

  end

  @impl true
  def handle_cast({:publish, topic, event}, state) do
    Util.JsonLog.check_log_file(topic)

    subscribers = EventsAgent.get_subscribers_to_notify(topic)
    # Logger.info("subs to publish: #{inspect(subscribers)}")
    Enum.map(
      subscribers,
      fn subscriber ->
        msg = Util.JsonLog.event_to_msg(topic, event)
        Server.notify(subscriber, msg)
      end
    )
    EventsAgent.publish_event(topic, event)
    {:noreply, state}
  end

end