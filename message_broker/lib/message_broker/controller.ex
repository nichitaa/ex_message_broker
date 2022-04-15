defmodule Controller do

  import Destructure
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    state = %{topic_subs: %{}, subs: %{}}
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Client API

  def add_topic(topic) do
    GenServer.cast(__MODULE__, {:add_topic, topic})
  end

  def publish_to_topic(topic, data) do
    GenServer.cast(__MODULE__, {:publish_to_topic, topic, data})
  end

  def add_subscriber_to_topic(topic, sub) do
    GenServer.cast(__MODULE__, {:add_subscriber_to_topic, topic, sub})
  end

  def unsubscribe_from_topic(topic, sub) do
    GenServer.cast(__MODULE__, {:unsubscribe_from_topic, topic, sub})
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:add_topic, topic}, state) do
    d(%{topic_subs}) = state
    if Map.has_key?(topic_subs, topic) do
      {:noreply, state}
    else
      topic_subs = Map.put(topic_subs, topic, [])
      {:noreply, %{state | topic_subs: topic_subs}}
    end
  end

  @impl true
  def handle_cast({:add_subscriber_to_topic, topic, sub}, state) do
    Logger.info("add_subscriber_to_topic state=#{inspect(state)}")
    d(%{topic_subs, subs}) = state
    if Map.has_key?(topic_subs, topic) do
      subs = Map.get(topic_subs, topic)
      case Enum.member?(subs, sub) do
        true ->
          :gen_tcp.send(sub, "you've already subscribed for topic #{topic}\r\n")
          {:noreply, %{state | topic_subs: topic_subs}}
        false ->
          subs = [sub | subs]
          topic_subs = Map.put(topic_subs, topic, subs)
          :gen_tcp.send(sub, "successfully subscribed to topic #{topic}\r\n")
          {:noreply, %{state | topic_subs: topic_subs, subs: Map.put(state.subs, Kernel.inspect(sub), sub)}}
      end
    else
      :gen_tcp.send(sub, "successfully subscribed to a newly created topic #{topic}\r\n")
      {
        :noreply,
        %{state | topic_subs: Map.put(topic_subs, topic, [sub]), subs: Map.put(subs, Kernel.inspect(sub), sub)}
      }
    end
  end

  @impl true
  def handle_cast({:unsubscribe_from_topic, topic, sub}, state) do
    d(%{topic_subs}) = state
    Logger.info("unsubscribe from topic=#{topic} sub=#{inspect(sub)}, current: #{inspect(topic_subs)}")
    if Map.has_key?(topic_subs, topic) do
      subs = Map.get(topic_subs, topic)
      case Enum.member?(subs, sub) do
        true ->
          subs = Enum.reject(subs, fn x -> x == sub end)
          topic_subs = Map.put(topic_subs, topic, subs)
          :gen_tcp.send(sub, "successfully unsubscribe from topic #{topic}\r\n")
          {:noreply, %{state | topic_subs: topic_subs}}
        false ->
          :gen_tcp.send(sub, "error: you are not subscribed to topic #{topic}\r\n")
          {:noreply, state}
      end
    else
      :gen_tcp.send(sub, "error: topic #{topic} does not exist\r\n")
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:publish_to_topic, topic, data}, state) do
    Logger.info("publish_to_topic state=#{inspect(state)}")
    d(%{topic_subs}) = state

    {:ok, logs} = Util.JsonLog.get()

    if Map.has_key?(topic_subs, topic) do

      # if we have subscribers
      subscribers_for_topic = Map.get(topic_subs, topic)
      if length(subscribers_for_topic) > 0 do

        # accumulate logs to update
        logs = Enum.reduce(
          # iterate thru this topic subscribers
          subscribers_for_topic,
          logs,
          fn sub, acc_logs ->
            # send the messages
            msg = Util.JsonLog.event_to_msg(data)
            :gen_tcp.send(sub, msg)

            # new log list of the single message log
            log_list = [Util.JsonLog.event_to_log(data)]

            # update message broker logs
            Map.update(
              acc_logs,
              # convert subscriber Port to String (this is the log key)
              Kernel.inspect(sub),
              # default: new Map %{topic: [single_log]}
              Map.put(%{}, topic, log_list),
              # in case there exists previous logs for this subscriber, just append to the topics logs list
              fn prev ->
                # return new map with updated message for the single topic
                Map.update(
                  prev,
                  topic,
                  log_list,
                  fn prev_topics ->
                    prev_topics ++ log_list
                  end
                )
              end
            )
          end
        )

        # update message broker logs
        Util.JsonLog.update(logs)

      end
      {:noreply, state}
    else
      # will never meet this condition
      Logger.info("error: topic #{topic} does not exist")
      {:noreply, state}
    end
  end

end