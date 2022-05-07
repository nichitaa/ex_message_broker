defmodule Worker.Controller do

  import Destructure
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  ## Privates

  defp send_next_event(topic, subscriber) do
    case Agent.Events.get_subscriber_next_message(topic, subscriber) do
      {:ok, next_event} ->
        {:ok, encode_event} = Poison.encode(next_event)
        msg = Util.JSONLog.event_to_msg(topic, encode_event)
        Server.notify(subscriber, msg)
      {:err, err_msg} ->
        Server.notify(subscriber, err_msg)
    end
  end

  defp acknowledge_from_logs(topic, subscriber, event_id) do
    {:ok, topic_logs} = Util.JSONLog.get(topic)
    subscriber_logs = topic_logs[Kernel.inspect(subscriber)]
    if subscriber_logs != nil and length(subscriber_logs) > 0 do
      pq = Util.JSONLog.list_to_pq(subscriber_logs)
      ack_log = PSQ.get(pq, event_id)
      if ack_log != nil do
        pq = PSQ.delete(pq, event_id)
        Server.notify(subscriber, "acknowledged from logs ev_id=#{event_id}")
        logs_list = Util.JSONLog.pq_to_list(pq)
        updated_topic_logs = Map.put(topic_logs, Kernel.inspect(subscriber), logs_list)
        Util.JSONLog.update(topic, updated_topic_logs)
        Agent.Subscriptions.update_subscriber_event_counter(subscriber, topic, :decrement)
        send_next_event(topic, subscriber)
      else
        # Agent.Subscriptions.update_subscriber_event_counter(subscriber, topic, :decrement)
        Server.notify(subscriber, "no_event_error: #{event_id}")
      end
    else
      Server.notify(subscriber, "no_event_error: #{event_id}")
    end
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

  @impl true
  def handle_cast({:acknowledge, topic, subscriber, event_id}, state) do

    Util.JSONLog.check_log_file(topic)

    case Agent.Subscriptions.is_topic_subscriber(topic, subscriber) do
      true ->
        # try acknowledge from session (2sec buffer)
        case Agent.Events.acknowledge_session_event(topic, subscriber, event_id) do
          {:ok, success_msg} ->
            # successfully acknowledged a message from Agent.Events state
            Server.notify(subscriber, success_msg)
            Agent.Subscriptions.update_subscriber_event_counter(subscriber, topic, :decrement)
            send_next_event(topic, subscriber)
          {:err, err_msg} ->
            # could not acknowledge a message from current state
            # try to do it from the persistent logs
            acknowledge_from_logs(topic, subscriber, event_id)
        end
      false ->
        Server.notify(subscriber, "error: not a topic #{topic} subscriber")
    end

    {:noreply, state}

  end

  @impl true
  def handle_cast({:unsubscribe, topic, subscriber}, state) do
    Agent.Subscriptions.remove_subscriber(topic, subscriber)

    # clean-up the logs message for this topic
    {:ok, logs} = Util.JSONLog.get(topic)
    subscriber_logs = logs[Kernel.inspect(subscriber)]
    if subscriber_logs != nil and length(subscriber_logs) > 0 do
      {_, logs} = Kernel.pop_in(logs, [Kernel.inspect(subscriber)])
      # update message broker logs
      Util.JSONLog.update(topic, logs)
    end
    Agent.Events.remove_subscriber_events(topic, subscriber)
    Agent.Subscriptions.reset_subscriber_cnt(topic, subscriber)
    Server.notify(subscriber, "successfully unsubscribe from topic #{topic}")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:publish, topic, event}, state) do
    Util.JSONLog.check_log_file(topic)
    # get all subscriber that can be notified (have empty ack queue) and send them the event
    subscribers = Agent.Subscriptions.get_subscribers_to_notify(topic)
    # update state for current session persistent events
    Agent.Events.publish_event(topic, event)
    # notify subscribers
    Enum.map(
      subscribers,
      fn subscriber ->
        msg = Util.JSONLog.event_to_msg(topic, event)
        Server.notify(subscriber, msg)
      end
    )
    {:noreply, state}
  end

end