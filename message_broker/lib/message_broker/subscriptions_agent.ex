defmodule SubscriptionsAgent do
  import Destructure
  require Logger
  use Agent

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def add_subscriber(topic, subscriber) do
    Agent.update(
      __MODULE__,
      fn subscriptions ->
        Map.update(
          subscriptions,
          topic,
          [subscriber],
          fn prev ->
            case Enum.member?(prev, subscriber) do
              true -> prev
              false -> [subscriber | prev]
            end
          end
        )
      end
    )
  end

  def remove_subscriber(topic, subscriber) do
    Agent.update(
      __MODULE__,
      fn subscriptions ->
        Map.update(
          subscriptions,
          topic,
          [],
          fn prev ->
            Enum.reject(prev, fn x -> x == subscriber end)
          end
        )
      end
    )
  end

  def get() do
    Agent.get(
      __MODULE__,
      fn subscriptions ->
        subscriptions
      end
    )
  end

  def check_or_create_topic(topic) do
    Agent.update(
      __MODULE__,
      fn subscriptions ->
        Map.update(subscriptions, topic, [], fn prev -> prev end)
      end
    )
  end

  def get_topic_subscribers(topic) do
    Agent.get(
      __MODULE__,
      fn subscriptions ->
        Map.get(subscriptions, topic, [])
      end
    )
  end

  def is_topic_subscriber(topic, subscriber) do
    Agent.get(
      __MODULE__,
      fn subscriptions ->
        topic_subscribers = Map.get(subscriptions, topic)
        Enum.member?(topic_subscribers, subscriber)
      end
    )
  end

end