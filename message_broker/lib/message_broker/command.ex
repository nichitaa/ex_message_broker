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
      unknown -> {:ok, {:error_unknown_command, unknown}}
    end

  end

  def run(command, subscriber)

  def run({:publish, topic, event}, publisher) do
    # check if the event is of the right format
    case Util.JsonLog.is_valid_event(event) do
      {:ok} ->
        # Logger.info(":publish topic=#{topic} publisher=#{inspect(publisher)} event=#{inspect(event)}")
        Counter.increment()
        Manager.publish(topic, event)
      {:err, reason} -> Logger.info("error: publisher send a bad event=#{inspect(event)}")
    end
  end

  def run({:subscribe, topic}, subscriber) do
    Manager.subscribe(topic, subscriber)
  end

  def run({:unsubscribe, topic}, subscriber) do
    Manager.unsubscribe(topic, subscriber)
  end

  def run({:acknowledge, topic, id}, subscriber) do
    Manager.acknowledge(topic, subscriber, id)
  end

  def run({:error_unknown_command, command}, subscriber) do
    Server.notify(subscriber, "error: unknown command: #{inspect(command)}")
  end

end
