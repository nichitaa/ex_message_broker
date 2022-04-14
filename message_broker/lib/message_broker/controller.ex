defmodule Controller do

  import Destructure
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    state = %{topic_subs: %{}}
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
    Logger.info("add_topic initial #{inspect(topic_subs)}")
    if Map.has_key?(topic_subs, topic) do
      Logger.info("add_topic topic=#{inspect(topic)} already exists")
      {:noreply, state}
    else
      topic_subs = Map.put(topic_subs, topic, [])
      Logger.info("add_topic after update: #{inspect(topic_subs)}")
      {:noreply, %{state | topic_subs: topic_subs}}
    end
  end

  @impl true
  def handle_cast({:add_subscriber_to_topic, topic, sub}, state) do
    Logger.info("add sub state: #{inspect(state)}")
    d(%{topic_subs}) = state
    Logger.info("add_subscriber_to_topic initial #{inspect(topic_subs)}")
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
          {:noreply, %{state | topic_subs: topic_subs}}
      end
    else
      :gen_tcp.send(sub, "successfully subscribed to a newly created topic #{topic}\r\n")
      {:noreply, %{state | topic_subs: Map.put(topic_subs, topic, [sub])}}
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
    d(%{topic_subs}) = state
    if Map.has_key?(topic_subs, topic) do
      subs = Map.get(topic_subs, topic)
      if length(subs) > 0 do
        Enum.each(
          subs,
          fn x ->
            :gen_tcp.send(x, data)
          end
        )
      end
      {:noreply, state}
    else
      # will never meet this condition
      Logger.info("error: topic #{topic} does not exist")
      {:noreply, state}
    end
  end

end