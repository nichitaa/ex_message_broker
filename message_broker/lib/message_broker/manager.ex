defmodule Manager do

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
          {:ok, logs} = Util.JsonLog.get(topic)
          subscriber_logs = logs[Kernel.inspect(subscriber)]
          if subscriber_logs != nil and length(subscriber_logs) > 0 do
            {_, logs} = Kernel.pop_in(logs, [Kernel.inspect(subscriber)])
            # update message broker logs
            Util.JsonLog.update(topic, logs)
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
    WorkerPool.route({:acknowledge, topic, subscriber, event_id, subscriptions})
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

    WorkerPool.route({:publish, topic, event, subscriptions})
    {:noreply, %{state | subscriptions: subscriptions}}
  end

end