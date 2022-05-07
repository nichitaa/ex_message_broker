defmodule App.UserEngagement do
  import Destructure
  use GenServer
  require Logger

  @ue_user_batch_size Application.fetch_env!(:rtp_sse, :ue_user_batch_size)
  @ue_flush_time Application.fetch_env!(:rtp_sse, :ue_flush_time)

  def start_link(args, opts \\ []) do
    d(%{dbServicePID}) = args
    Logger.info("User engagement start_link #{inspect(args)}")
    state = d(
      %{
        dbServicePID,
        users: %{},
      }
    )
    GenServer.start_link(__MODULE__, state, opts)
  end

  ## Client API

  def add_user_engagement(pid, user_id, score, score_meta) do
    GenServer.cast(pid, {:add_user_engagement, user_id, score, score_meta})
  end

  ## Privates

  defp flush_state_loop() do
    selfPID = self()
    spawn(
      fn ->
        Process.sleep(@ue_flush_time)
        GenServer.cast(selfPID, {:flush_state})
      end
    )
  end

  ## Callbacks

  @impl true
  def init(state) do
    flush_state_loop()
    {:ok, state}
  end

  @impl true
  def handle_cast({:flush_state}, state) do
    d(%{users, dbServicePID}) = state
    user_ids = Map.keys(users)
    if length(user_ids) > 0 do
      App.DBService.bulk_insert_users_engagements(dbServicePID, users)
    end
    flush_state_loop()
    {:noreply, %{state | users: %{}}}
  end

  @impl true
  def handle_cast({:add_user_engagement, user_id, score, score_meta}, state) do
    d(%{users, dbServicePID}) = state
    #    Logger.info("EngWorker meta: #{inspect(score_meta)}")

    user_data = Map.get(users, user_id)
    # user_scores = Map.get(user_data, :scores)

    if user_data === nil do
      users = Map.put(users, user_id, %{scores: [score], meta: [score_meta]})
      {:noreply, %{state | users: users}}
    else

      users = Map.update(
        users,
        user_id,
        score,
        fn prev -> %{scores: [score | prev.scores], meta: [score_meta | prev.meta]} end
      )
      {:noreply, %{state | users: users}}
    end

  end

end