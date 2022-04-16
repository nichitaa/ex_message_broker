defmodule Util.JsonLog do
  @json_filename Application.fetch_env!(:message_broker, :json_filename)
  require Logger

  def get() do
    with {:ok, body} <- File.read(@json_filename),
         {:ok, json} <- Poison.decode(body), do: {:ok, json}
  end

  def update(content) do
    File.write(@json_filename, Poison.encode!(content), [:binary])
  end

  def event_to_log(event) do
    case Poison.decode(event, as: %EventDto{}) do
      {:ok, dto} -> %{"id": dto.id, "msg": dto.msg, "timestamp": :os.system_time(:milli_seconds)}
      {:error, reason} -> %{"id": nil, "error": "event is not of an accepted format"}
    end
  end

  def event_to_msg(topic, event) do
    case Poison.decode(event, as: %EventDto{}) do
      {:ok, dto} -> Poison.encode!(%{"msg": dto.msg, "id": dto.id, "topic": topic})
      _ -> "error: publisher send an invalid event"
    end
  end

  def is_valid_event(event) do
    case Poison.decode(event, as: %EventDto{}) do
      {:ok, dto} -> {:ok}
      _ -> {:err, "event is not of an accepted format"}
    end
  end

end