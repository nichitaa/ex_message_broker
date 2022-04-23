defmodule Util.JsonLog do
  @logs_dir Application.fetch_env!(:message_broker, :logs_dir)
  @clean_log_file Application.fetch_env!(:message_broker, :clean_log_file)

  import Destructure
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    # Logger.info("util json log start_link opts=#{inspect(opts)}")
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @impl true
  def init(state) do
    # Logger.info("util json log init")
    {:ok, state}
  end

  def clear_logs_on_startup() do
    if @clean_log_file do
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

  def get(topic) do
    GenServer.call(__MODULE__, {:get, topic})
  end

  @impl true
  def handle_call({:get, topic}, _from, state) do
    {:message_queue_len, len} = Process.info(self(), :message_queue_len)
    Logger.info("json :get mq_len=#{inspect(len)}")
    start_time = :os.system_time(:milli_seconds)

    path = "#{@logs_dir}/#{topic}.json"
    response =
      with {:ok, body} <- File.read(path),
           {:ok, json} <- Poison.decode(body), do: {:ok, json}

    end_time = :os.system_time(:milli_seconds)
    execution_time = end_time - start_time
    Logger.info("json :get exec_time=#{inspect(execution_time)}")
    {:reply, response, state}
  end


  def update(topic, updated_logs) do
    GenServer.cast(__MODULE__, {:update, topic, updated_logs})
  end

  @impl true
  def handle_cast({:update, topic, updated_logs}, state) do
    {:message_queue_len, len} = Process.info(self(), :message_queue_len)
    Logger.info("json :update mq_len=#{inspect(len)}")
    path = "#{@logs_dir}/#{topic}.json"
    File.write(path, Poison.encode!(updated_logs), [:binary])
    {:noreply, state}
  end

  def event_to_log(event) do
    case Poison.decode(event, as: %EventDto{}) do
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
    case Poison.decode(event, as: %EventDto{}) do
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
    case Poison.decode(event, as: %EventDto{}) do
      {:ok, dto} -> {:ok}
      _ -> {:err, "event is not of an accepted format"}
    end
  end

  def list_to_pq(list) do
    # inverse pq (higher priority pops out first)
    # using event_id as queue item key
    pq = PSQ.new(fn x -> -x["priority"] end, &(&1["id"]))
    pq = Enum.into(list, pq)
    pq
  end

  def pq_to_list(pq) do
    list = Enum.to_list(pq)
    list
  end

end