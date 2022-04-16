defmodule Command do

  import Destructure
  require Logger

  @tweet_producer_host Application.fetch_env!(:message_broker, :tweet_producer_host)
  @tweet_producer_port Application.fetch_env!(:message_broker, :tweet_producer_port)
  @publish_command Application.fetch_env!(:message_broker, :publish_command)
  @subscribe_command Application.fetch_env!(:message_broker, :subscribe_command)
  @acknowledge_command Application.fetch_env!(:message_broker, :acknowledge_command)
  @unsubscribe_command Application.fetch_env!(:message_broker, :unsubscribe_command)

  ## Client API

  def parse(line) do

    parsed = String.trim(line, "\r\n")
             |> String.split(" ", parts: 3)

    # Logger.info("parse len=#{inspect(length(parsed))} parsed=#{inspect(parsed)}")
    case parsed do
      [@publish_command, topic, event] -> {:ok, {:publish, topic, event}}
      [@subscribe_command, topic] -> {:ok, {:subscribe, topic}}
      [@unsubscribe_command, topic] -> {:ok, {:unsubscribe, topic}}
      [@acknowledge_command, topic, id] -> {:ok, {:acknowledge, topic, id}}
      unknown -> Logger.info("error: unknown command #{inspect(unknown)}")
    end

  end

  def run(command, subscriber)

  def run({:publish, topic, event}, _subscriber) do
    # check if the event is of the right format
    case Util.JsonLog.is_valid_event(event) do
      {:ok} -> Controller.publish(topic, event)
      {:err, reason} -> Logger.info("error: publisher send a bad event=#{inspect(event)}")
    end
  end

  def run({:subscribe, topic}, subscriber) do
    Controller.subscribe(topic, subscriber)
  end

  def run({:unsubscribe, topic}, subscriber) do
    Controller.unsubscribe(topic, subscriber)
  end

  def run({:acknowledge, topic, id}, subscriber) do
    Controller.acknowledge(topic, subscriber, id)
  end

end
