defmodule Command do

  import Destructure
  require Logger

  @publish_command Application.fetch_env!(:message_broker, :publish_command)
  @subscribe_command Application.fetch_env!(:message_broker, :subscribe_command)
  @acknowledge_command Application.fetch_env!(:message_broker, :acknowledge_command)
  @unsubscribe_command Application.fetch_env!(:message_broker, :unsubscribe_command)

  ## Client API

  def parse(line) do
    line = String.trim(line)

    parsed = String.trim(line, "\r\n")
             |> String.split(" ", parts: 3)

    # Logger.info("parse len=#{inspect(length(parsed))} parsed=#{inspect(parsed)}")
    case parsed do
      [@publish_command, topic, event] -> {:ok, {:publish, topic, event}}
      [@subscribe_command, topic] -> {:ok, {:subscribe, topic}}
      [@unsubscribe_command, topic] -> {:ok, {:unsubscribe, topic}}
      [@acknowledge_command, topic, id] when Kernel.is_binary(id) == true -> {:ok, {:acknowledge, topic, id}}
      unknown -> {:ok, {:error_unknown_command, unknown}}
    end

  end

  def run(command, subscriber)

  def run({:publish, topic, event}, publisher) do
    # check if the event is of the right format
    case Util.JSONLog.is_valid_event(event) do
      {:ok} ->
        App.Manager.publish(topic, event)
      {:err, reason} -> Logger.info("error: publisher send a bad event=#{inspect(event)}")
    end
  end

  def run({:subscribe, topic}, subscriber) do
    App.Manager.subscribe(topic, subscriber)
  end

  def run({:unsubscribe, topic}, subscriber) do
    App.Manager.unsubscribe(topic, subscriber)
  end

  def run({:acknowledge, topic, id}, subscriber) do
    App.Manager.acknowledge(topic, subscriber, id)
  end

  def run({:error_unknown_command, command}, subscriber) do
    Server.notify(subscriber, "error: unknown command: #{inspect(command)}")
  end

end
