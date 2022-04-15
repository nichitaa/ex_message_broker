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

  def event_to_msg(event) do
    case Poison.decode(event, as: %EventDto{}) do
      {:ok, dto} -> dto.msg <> "\r\n"
      {:error, reason} -> "error: publisher send an invalid event" <> "\r\n"
    end
  end

  def is_valid_event(event) do
    case Poison.decode(event, as: %EventDto{}) do
      {:ok, dto} -> {:ok}
      {:error, reason} -> {:err, "event is not of an accepted format"}
    end
  end

end