defmodule App.Manager do

  import Destructure
  use GenServer
  require Logger

  @reset_previous_topic_subscriber Application.fetch_env!(:message_broker, :reset_previous_topic_subscriber)
  @logs_dir Application.fetch_env!(:message_broker, :logs_dir)

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
    if @reset_previous_topic_subscriber do
      Process.send_after(self(), :reset_previous_topic_subscriber, 100)
    end
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
    App.WorkerPool.route({:unsubscribe, topic, subscriber})
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

  @impl true
  def handle_info(:reset_previous_topic_subscriber, state) do
    Path.wildcard(@logs_dir <> "/*.json")
    |> Enum.map(fn t -> String.replace(t, [@logs_dir <> "/", ".json"], "")end)
    |> Enum.each(
         fn topic ->
           Agent.Subscriptions.check_or_create_topic(topic)
           {:ok, logs} = Util.JSONLog.get(topic)
           Map.keys(logs)
           |> Enum.each(
                fn subscriber ->
                  port = :erlang.list_to_port(Kernel.to_charlist(subscriber))
                  Agent.Subscriptions.add_subscriber(topic, port)
                end
              )
         end
       )
    {:noreply, state}
  end

end