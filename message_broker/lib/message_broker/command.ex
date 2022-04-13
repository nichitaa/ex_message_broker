defmodule Command do

  import Destructure
  require Logger

  @tweet_producer_host Application.fetch_env!(:message_broker, :tweet_producer_host)
  @tweet_producer_port Application.fetch_env!(:message_broker, :tweet_producer_port)
  @delimiter Application.fetch_env!(:message_broker, :delimiter)
  @publish_command Application.fetch_env!(:message_broker, :publish_command)
  @subscribe_command Application.fetch_env!(:message_broker, :subscribe_command)
  @unsubscribe_command Application.fetch_env!(:message_broker, :unsubscribe_command)

  ## Client API

  def parse(line) do

    parsed = String.trim(line, "\r\n")
             |> String.split(" ", parts: 3)

    Logger.info("case parsed: #{inspect(length(parsed))} parsed: #{inspect(parsed)}")
    case parsed do
      [@publish_command, topic, data] -> {:ok, {:publish, topic, data}}
      [@subscribe_command, topic] -> {:ok, {:subscribe, topic}}
      [@unsubscribe_command, topic] -> Logger.info("will unsubscribe here")
      unknown -> Logger.info("unknown command #{inspect(unknown)}")
    end

  end

  def run(command, socket)

  def run({:publish, topic, data}, socket) do
    Logger.info("Received for topic #{inspect(topic)} content #{data}")
    decoded = Poison.decode!(data, as: %TweetDto{})
    {:ok, "[Command] run :publish\r\n"}
  end

  def run({:subscribe, topic}, socket) do
    Logger.info("will subscribe for topic #{inspect(topic)}, socket #{inspect(socket)}")
    {:ok, "[Command] run :subscribe\r\n"}
  end

end
