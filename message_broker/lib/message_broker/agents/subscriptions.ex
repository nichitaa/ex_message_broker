defmodule Agent.Subscriptions do
  import Destructure
  require Logger
  use Agent

  def start_link(initial_value) do
    initial_value = %{
      subscriptions: %{},
      subscriber_events_cnt: %{}
    }
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def add_subscriber(topic, subscriber) do
    Agent.update(
      __MODULE__,
      fn state ->
        %{
          state |
          subscriptions: Map.update(
            state.subscriptions,
            topic,
            [subscriber],
            fn prev ->
              case Enum.member?(prev, subscriber) do
                true -> prev
                false -> [subscriber | prev]
              end
            end
          )
        }
      end
    )
  end

  def remove_subscriber(topic, subscriber) do
    Agent.update(
      __MODULE__,
      fn state ->
        %{
          state |
          subscriptions: Map.update(
            state.subscriptions,
            topic,
            [],
            fn prev ->
              Enum.reject(prev, fn x -> x == subscriber end)
            end
          )
        }
      end
    )
  end

  def update_subscriber_event_counter(subscriber, topic, operator) do
    Agent.update(
      __MODULE__,
      fn state ->
        subscriber_events_cnt =
          Map.update(
            state.subscriber_events_cnt,
            Kernel.inspect(subscriber),
            Map.put(%{}, topic, 1),
            fn prev ->
              case operator do
                :increment -> Map.update(prev, topic, 1, fn nr -> nr + 1 end)
                :decrement -> Map.update(prev, topic, 1, fn nr -> nr - 1 end)
              end
            end
          )
        %{state | subscriber_events_cnt: subscriber_events_cnt}
      end
    )
  end

  def get_subscriber_cnt(subscriber, topic) do
    Agent.get(
      __MODULE__,
      fn state ->
        cnt = Kernel.get_in(state.subscriber_events_cnt, [Kernel.inspect(subscriber), topic])
        case cnt do
          nil -> 0
          _ -> cnt
        end
      end
    )
  end

  def reset_subscriber_cnt(topic, subscriber) do
    Agent.update(
      __MODULE__,
      fn state ->
        %{
          state |
          subscriber_events_cnt: Kernel.put_in(
            state.subscriber_events_cnt,
            [Kernel.inspect(subscriber), topic],
            0
          )
        }
      end
    )
  end

  def check_or_create_topic(topic) do
    Agent.update(
      __MODULE__,
      fn state ->
        %{
          state |
          subscriptions: Map.update(state.subscriptions, topic, [], &(&1))
        }
      end
    )
  end

  def get_topic_subscribers(topic) do
    Agent.get(
      __MODULE__,
      fn state ->
        Map.get(state.subscriptions, topic, [])
      end
    )
  end

  def is_topic_subscriber(topic, subscriber) do
    Agent.get(
      __MODULE__,
      fn state ->
        topic_subscribers = Map.get(state.subscriptions, topic)
        Enum.member?(topic_subscribers, subscriber)
      end
    )
  end

  @doc """
  For debug purposes, use it to see current subscriptions
  """
  def info() do
    Agent.get(__MODULE__, &(&1))
  end

end