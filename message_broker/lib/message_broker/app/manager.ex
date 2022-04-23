defmodule App.Manager do

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
    GenServer.cast(__MODULE__, {:acknowledge, topic, subscriber, event_id})
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:subscribe, topic, subscriber}, state) do
    Agent.Subscriptions.add_subscriber(topic, subscriber)
    Server.notify(subscriber, "successfully subscribed to topic #{topic}")
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
    Server.notify(subscriber, "successfully unsubscribe from topic #{topic}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:acknowledge, topic, subscriber, event_id}, state) do
    Agent.Subscriptions.check_or_create_topic(topic)
    App.WorkerPool.route({:acknowledge, topic, subscriber, event_id})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:publish, topic, event}, state) do
    Agent.Subscriptions.check_or_create_topic(topic)
    App.WorkerPool.route({:publish, topic, event})
    {:noreply, state}
  end

end