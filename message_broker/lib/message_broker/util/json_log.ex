defmodule Util.JSONLog do

  @logs_dir Application.fetch_env!(:message_broker, :logs_dir)
  @clean_logs_on_startup Application.fetch_env!(:message_broker, :clean_logs_on_startup)
  @debug_io_time Application.fetch_env!(:message_broker, :debug_io_time)

  import Destructure
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  ## Privates

  defp log_message_queue_len() do
    {:message_queue_len, len} = Process.info(self(), :message_queue_len)
    Logger.info("JSON-logs mq_len=#{inspect(len)}")
  end

  ## Client API

  def get(topic) do
    GenServer.call(__MODULE__, {:get, topic})
  end

  def update(topic, updated_logs) do
    GenServer.cast(__MODULE__, {:update, topic, updated_logs})
  end

  def event_to_log(event) do
    case Poison.decode(event, as: %DTO.Event{}) do
      {:ok, dto} ->
        %{
          "id" => dto.id,
          "msg" => dto.msg,
          "priority" => dto.priority,
          "timestamp" => :os.system_time(:milli_seconds)
        }
      {:error, reason} ->
        %{"error": "event is not of an accepted format"}
    end
  end

  def event_to_msg(topic, event) do
    case Poison.decode(event, as: %DTO.Event{}) do
      {:ok, dto} ->
        Poison.encode!(
          %{
            "msg": dto.msg,
            "id": dto.id,
            "priority": dto.priority,
            "topic": topic
          }
        )
      _ ->
        "error: publisher send an invalid event"
    end
  end

  def is_valid_event(event) do
    case Poison.decode(event, as: %DTO.Event{}) do
      {:ok, dto} -> {:ok}
      _ -> {:err, "event is not of an accepted format"}
    end
  end

  @doc """
  Enumerable List to inverse Priority Queue (PSQ) - events with higher priority pops out firs
  Using `:id` as queue item key, and `:priority` as event priority
  """
  def list_to_pq(list) do
    pq = PSQ.new(fn x -> -x["priority"] end, &(&1["id"]))
    Enum.into(list, pq)
  end

  @doc """
  Priority queue (PSQ) to enumerable List
  """
  def pq_to_list(pq) do
    Enum.to_list(pq)
  end

  def clear_logs_on_startup() do
    if @clean_logs_on_startup do
      File.rm_rf(@logs_dir)
    end
  end

  def check_log_file(topic) do
    path = "#{@logs_dir}/#{topic}.json"
    exists = File.exists?(path)
    # create a json log file
    if !exists do
      File.mkdir_p!(Path.dirname(path))
      {:ok, file} = File.open(path, [:write])
      file
      |> :file.position(:bof)
      |> :file.truncate()
      IO.binwrite(file, "{}")
      File.close(file)
    end
  end

  ## Callbacks

  @impl true
  def handle_call({:get, topic}, _from, state) do
    # log_message_queue_len()
    start_time = :os.system_time(:milli_seconds)

    path = "#{@logs_dir}/#{topic}.json"
    response =
      with {:ok, body} <- File.read(path),
           {:ok, json} <- Poison.decode(body), do: {:ok, json}

    end_time = :os.system_time(:milli_seconds)
    execution_time = end_time - start_time

    if @debug_io_time do
      Logger.info("JSON-logs File.read time=#{inspect(execution_time)}")
    end
    {:reply, response, state}
  end

  @impl true
  def handle_cast({:update, topic, updated_logs}, state) do
    # log_message_queue_len()
    path = "#{@logs_dir}/#{topic}.json"
    File.write(path, Poison.encode!(updated_logs), [:binary])
    {:noreply, state}
  end

end

