defmodule Handler do

  @db_tweets_collection Application.fetch_env!(:change_stream, :db_tweets_collection)
  @db_users_collection Application.fetch_env!(:change_stream, :db_users_collection)
  @db_users_engagements_collection Application.fetch_env!(:change_stream, :db_users_engagements_collection)
  @mb_host Application.fetch_env!(:change_stream, :mb_host)
  @mb_port Application.fetch_env!(:change_stream, :mb_port)

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    collection = opts[:collection]
    me = opts[:name]
    state = %{
      counter: 0,
      last_resume_token: nil,
      collection: collection,
      me: me,
      mb_socket: nil
    }
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Privates

  defp new_token(me, token) do
    GenServer.cast(me, {:token, token})
  end

  defp new_doc(me, doc) do
    GenServer.cast(me, {:doc, doc})
  end

  defp process_doc(state, doc) do
    collection = state.collection
    message_broker = state.mb_socket
    full_document = doc["fullDocument"]

    event =
      case collection do
        @db_tweets_collection -> Utils.to_tweet_topic_event(full_document)
        @db_users_collection -> Utils.to_user_topic_event(full_document)
        _ -> nil
      end

    if event != nil do
      :gen_tcp.send(message_broker, event)
    end
  end

  defp get_cursor(nil, collection_name, me) do
    Mongo.watch_collection(:mongo, collection_name, [], fn token -> new_token(me, token) end, max_time: 2_000)
  end

  defp get_cursor(last_resume_token, collection_name, me) do
    Mongo.watch_collection(
      :mongo,
      collection_name,
      [],
      fn token -> new_token(me, token) end,
      max_time: 2_000,
      resume_after: last_resume_token
    )
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, mb_socket} =
      case :gen_tcp.connect(@mb_host, @mb_port, [:binary, active: false, keepalive: true, reuseaddr: true,]) do
        {:ok, mb_socket} ->
          {:ok, mb_socket}
        {:error, reason} ->
          Logger.info("Error: failed to connect to MessageBroker, reason: #{inspect(reason)}")
      end
    Logger.info(
      "#{inspect(state.me)} successfully connected to message broker socket=#{inspect mb_socket}, watching collection=#{
        inspect(state.collection)
      }"
    )
    Process.send_after(self(), :connect, 3000)
    {:ok, %{state | mb_socket: mb_socket}}
  end

  @impl true
  def handle_info({:DOWN, _, :process, _pid, reason}, state) do
    Logger.info("#Cursor process is down, reason=#{inspect(reason)}, will reconnect")
    Process.send_after(self(), :connect, 2000)
    {:noreply, state}
  end

  @impl true
  def handle_info(:connect, state) do
    # Span a new process
    pid = spawn(
      fn ->
        Enum.each(get_cursor(state.last_resume_token, state.collection, state.me), fn doc -> new_doc(state.me, doc) end)
      end
    )
    # Monitor the process
    Process.monitor(pid)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:doc, doc}, state) do
    process_doc(state, doc)
    {:noreply, %{state | counter: state.counter + 1}}
  end

  @impl true
  def handle_cast({:token, token}, state) do
    {:noreply, %{state | last_resume_token: token}}
  end

end