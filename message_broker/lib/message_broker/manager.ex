defmodule Manager do

  import Destructure
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    state = %{}
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
    Server.notify(subscriber, "received ack from manager API")
    GenServer.cast(__MODULE__, {:acknowledge, topic, subscriber, event_id})
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:subscribe, topic, subscriber}, state) do
    SubscriptionsAgent.add_subscriber(topic, subscriber)
    Server.notify(subscriber, "successfully subscribed to topic #{topic}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:unsubscribe, topic, subscriber}, state) do
    SubscriptionsAgent.remove_subscriber(topic, subscriber)

    # clean-up the logs message for this topic
    {:ok, logs} = Util.JsonLog.get(topic)
    subscriber_logs = logs[Kernel.inspect(subscriber)]
    if subscriber_logs != nil and length(subscriber_logs) > 0 do
      {_, logs} = Kernel.pop_in(logs, [Kernel.inspect(subscriber)])
      # update message broker logs
      Util.JsonLog.update(topic, logs)
    end

    Server.notify(subscriber, "successfully unsubscribe from topic #{topic}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:acknowledge, topic, subscriber, event_id}, state) do
    Server.notify(subscriber, "received ack from manager handle_cast")
    WorkerPool.route({:acknowledge, topic, subscriber, event_id})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:publish, topic, event}, state) do
    SubscriptionsAgent.check_or_create_topic(topic)

    WorkerPool.route({:publish, topic, event})
    {:noreply, state}
  end

end