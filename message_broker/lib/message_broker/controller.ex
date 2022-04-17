defmodule Controller do

  import Destructure
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    state = %{subscriptions: %{}}
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Client API

  def publish(topic, event) do
    GenServer.cast(__MODULE__, {:publish, topic, event})
  end

  def subscribe(topic, subscriber) do
    GenServer.cast(__MODULE__, {:subscribe, topic, subscriber})
  end

  def unsubscribe(topic, subscriber) do
    GenServer.cast(__MODULE__, {:unsubscribe, topic, subscriber})
  end

  def acknowledge(topic, subscriber, event_id) do
    GenServer.cast(__MODULE__, {:acknowledge, topic, subscriber, event_id})
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:subscribe, topic, subscriber}, state) do
    d(%{subscriptions}) = state

    # check if topic exists
    if Map.has_key?(subscriptions, topic) do

      topic_subscribers = Map.get(subscriptions, topic)
      case Enum.member?(topic_subscribers, subscriber) do
        true ->
          Server.notify(subscriber, "error: already subscribed for topic #{topic}")
          {:noreply, state}
        false ->
          Server.notify(subscriber, "successfully subscribed to topic #{topic}")
          {
            :noreply,
            %{
              state |
              subscriptions: Map.update(subscriptions, topic, [subscriber], fn prev -> [subscriber | prev] end)
            }
          }
      end
    else
      Server.notify(subscriber, "successfully subscribed to a newly created topic #{topic}")
      {
        :noreply,
        %{
          state |
          subscriptions: Map.put(state.subscriptions, topic, [subscriber])
        }
      }
    end
  end

  @impl true
  def handle_cast({:unsubscribe, topic, subscriber}, state) do
    d(%{subscriptions}) = state

    if Map.has_key?(subscriptions, topic) do

      topic_subscribers = Map.get(subscriptions, topic)
      case Enum.member?(topic_subscribers, subscriber) do
        true ->
          # remove subscriptions from state
          topic_subscribers = Enum.reject(topic_subscribers, fn x -> x == subscriber end)
          Server.notify(subscriber, "successfully unsubscribe from topic #{topic}")

          # clean-up the logs message for this topic
          {:ok, logs} = Util.JsonLog.get()
          subscriber_logs = logs[Kernel.inspect(subscriber)][topic]
          if subscriber_logs != nil and length(subscriber_logs) > 0 do
            {_, logs} = Kernel.pop_in(logs, [Kernel.inspect(subscriber), topic])
            # update message broker logs
            Util.JsonLog.update(logs)
          end

          {
            :noreply,
            %{state | subscriptions: Map.put(subscriptions, topic, topic_subscribers)}
          }
        false ->
          Server.notify(subscriber, "error: you are not subscribed to topic #{topic}")
          {:noreply, state}
      end

    else
      Server.notify(subscriber, "error: topic #{topic} does not exist")
      {:noreply, state}
    end

  end

  @impl true
  def handle_cast({:acknowledge, topic, subscriber, event_id}, state) do
    d(%{subscriptions}) = state

    if Map.has_key?(subscriptions, topic) do

      # check if it is subscribed for the topic
      topic_subscribers = Map.get(subscriptions, topic)
      case Enum.member?(topic_subscribers, subscriber) do
        true ->

          {:ok, logs} = Util.JsonLog.get()

          # subscriber exists
          subscriber_logs = logs[Kernel.inspect(subscriber)][topic]

          # check if there are messages in the corresponding topics list
          if subscriber_logs != nil and length(subscriber_logs) > 0 do

            subscriber_logs_pq = Util.JsonLog.list_to_pq(subscriber_logs)
            # get by event id
            ack_event = PSQ.get(subscriber_logs_pq, event_id)

            if ack_event != nil do
              subscriber_logs_pq = PSQ.delete(subscriber_logs_pq, event_id)
              subscriber_logs = Util.JsonLog.pq_to_list(subscriber_logs_pq)
              logs = Kernel.put_in(
                logs,
                [Kernel.inspect(subscriber), topic],
                subscriber_logs
              )

              # update message broker logs
              Util.JsonLog.update(logs)

              # send the next event to the subscriber, so it can send a new ack
              if length(subscriber_logs) > 0 do
                {next_log, _pq} = PSQ.pop(subscriber_logs_pq)
                {:ok, next_event} = Poison.encode(next_log)
                msg = Util.JsonLog.event_to_msg(topic, next_event)
                Server.notify(subscriber, msg)
              end

            else
              Server.notify(subscriber, "error: event with id #{event_id} does not exists")
            end
          end

        false ->
          Server.notify(
            subscriber,
            "error: you are not subscribed to topic #{topic} and therefor can not send acknowledge messages\r\n"
          )
      end

    else
      Server.notify(subscriber, "error: topic #{topic} does not exist")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:publish, topic, event}, state) do
    d(%{subscriptions}) = state

    # create new topic if does not exists
    subscriptions =
      if !Map.has_key?(subscriptions, topic) do
        Map.put(subscriptions, topic, [])
      else
        subscriptions
      end

    if Map.has_key?(subscriptions, topic) do

      # if we have subscribers
      topic_subscribers = Map.get(subscriptions, topic)
      if length(topic_subscribers) > 0 do

        # get all message broker logs
        {:ok, logs} = Util.JsonLog.get()

        # accumulate logs to update
        logs = Enum.reduce(
          # iterate thru this topic subscribers
          topic_subscribers,
          logs,
          fn subscriber, acc_logs ->

            # send the message to the subscriber only if previous message have been acknowledged
            sub_logs_for_topic = logs[Kernel.inspect(subscriber)][topic]
            if sub_logs_for_topic == nil or length(sub_logs_for_topic) == 0 do
              msg = Util.JsonLog.event_to_msg(topic, event)
              Server.notify(subscriber, msg)
            end

            # new log event
            event_log = Util.JsonLog.event_to_log(event)

            # update message broker logs
            Map.update(
              acc_logs,
              # convert subscriber Port to String (this is the log key)
              Kernel.inspect(subscriber),
              # default: new Map %{topic: [event_log]}
              Map.put(%{}, topic, [event_log]),
              # in case there exists previous logs for this subscriber, just append to the topics logs list
              fn prev ->
                # return new map with updated message for the single topic
                Map.update(
                  prev,
                  topic,
                  [event_log],
                  fn prev_topic_logs ->
                    # priority queue
                    pq = Util.JsonLog.list_to_pq(prev_topic_logs)
                    pq = PSQ.put(pq, event_log)
                    list = Util.JsonLog.pq_to_list(pq)
                    list
                  end
                )
              end
            )
          end
        )

        # update message broker logs
        Util.JsonLog.update(logs)
      end
    end

    {:noreply, %{state | subscriptions: subscriptions}}
  end

end