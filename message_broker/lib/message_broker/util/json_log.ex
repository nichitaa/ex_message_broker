defmodule Util.JsonLog do
  @json_filename Application.fetch_env!(:message_broker, :json_filename)
  @clean_log_file Application.fetch_env!(:message_broker, :clean_log_file)

  require Logger

  def check_log_file() do
    exists = File.exists?(@json_filename)
    # create a json log file
    if !exists or @clean_log_file do
      {:ok, file} = File.open(@json_filename, [:write])
      file
      |> :file.position(:bof)
      |> :file.truncate()
      IO.binwrite(file, "{}")
      File.close(file)
    end
  end

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