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

    Logger.info("case parsed: #{inspect(length(parsed))} parsed: #{inspect(parsed)}")
    case parsed do
      [@publish_command, topic, data] -> {:ok, {:publish, topic, data}}
      [@subscribe_command, topic] -> {:ok, {:subscribe, topic}}
      [@unsubscribe_command, topic] -> {:ok, {:unsubscribe, topic}}
      [@acknowledge_command, topic, id] -> {:ok, :acknowledge, topic, id}
      unknown -> Logger.info("unknown command #{inspect(unknown)}")
    end

  end

  def run(command, socket)

  def run({:publish, topic, data}, socket) do
    Logger.info("Received for topic #{inspect(topic)} data=#{inspect(data)}")
    case Util.JsonLog.is_valid_event(data) do
      {:ok} -> Controller.add_topic(topic)
               Controller.publish_to_topic(topic, data)
      {:err, reason} -> Logger.info("received a bad event: #{inspect(data)}")
    end
    {:ok, "[Command] run :publish\r\n"}
  end

  def run({:subscribe, topic}, socket) do
    Logger.info("will subscribe for topic #{inspect(topic)}, socket #{inspect(socket)}")
    Controller.add_subscriber_to_topic(topic, socket)
    {:ok, "[Command] run :subscribe\r\n"}
  end

  def run({:unsubscribe, topic}, socket) do
    Logger.info("will unsubscribe from topic=#{inspect(topic)}, socket #{inspect(socket)}")
    Controller.unsubscribe_from_topic(topic, socket)
    {:ok, "[Command] run :unsubscribe\r\n"}
  end

  def run({:acknowledge, topic, id}, socket) do
    Logger.info("acknowledge for topic=#{inspect(topic)}, message id=#{inspect(id)} socket=#{inspect(socket)}")
    {:ok, "[Command] run :acknowledge\r\n"}
  end

end
