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
    # Logger.info("worker command=#{inspect(command)}")
    GenServer.cast(self(), command)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:acknowledge, topic, subscriber, event_id, subscriptions}, state) do

    if Map.has_key?(subscriptions, topic) do

      # check if it is subscribed for the topic
      topic_subscribers = Map.get(subscriptions, topic)
      case Enum.member?(topic_subscribers, subscriber) do
        true ->
          {:ok, logs} = Util.JsonLog.get(topic)

          # subscriber exists
          subscriber_logs = logs[Kernel.inspect(subscriber)]

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
                [Kernel.inspect(subscriber)],
                subscriber_logs
              )

              # update message broker logs
              Util.JsonLog.update(topic, logs)

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
  def handle_cast({:publish, topic, event, subscriptions}, state) do

    # Logger.info("controller topic=#{topic}, event=#{inspect(event)}, subscriptions=#{inspect(subscriptions)}")
    # check topic log file
    Util.JsonLog.check_log_file(topic)

    if Map.has_key?(subscriptions, topic) do

      # if we have subscribers
      topic_subscribers = Map.get(subscriptions, topic)
      if length(topic_subscribers) > 0 do

        # get all message broker logs
        {:ok, logs} = Util.JsonLog.get(topic)
        # Logger.info("controller logs=#{inspect(logs)}")

        # accumulate logs to update
        logs = Enum.reduce(
          # iterate thru this topic subscribers
          topic_subscribers,
          logs,
          fn subscriber, acc_logs ->

            # send the message to the subscriber only if previous message have been acknowledged
            sub_logs_for_topic = logs[Kernel.inspect(subscriber)]
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
              # default: [event_log]
              [event_log],
              # in case there exists previous logs for this subscriber, just append to the topics logs list
              fn prev ->
                # priority queue
                pq = Util.JsonLog.list_to_pq(prev)
                pq = PSQ.put(pq, event_log)
                list = Util.JsonLog.pq_to_list(pq)
                list
              end
            )
          end
        )

        # update message broker logs
        Util.JsonLog.update(topic, logs)
      end
    end

    {:noreply, state}
  end

end