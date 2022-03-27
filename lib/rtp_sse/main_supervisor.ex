defmodule MainSupervisor do

  @ms_delay Application.fetch_env!(:rtp_sse, :ms_delay)
  @sse_base_url Application.fetch_env!(:rtp_sse, :sse_base_url)

  use Supervisor
  import Destructure
  require Logger

  def start_link(init_arg) do
    name = String.to_atom("Main_#{Kernel.inspect(init_arg.socket)}")
    Supervisor.start_link(__MODULE__, init_arg, name: name)
  end

  ## Privates

  defp start_stream(args, supervisorsNames, index) do
    Logger.info("[MainSupervisor] Starting Supervisors-workers tree for SSE stream no #{index}")

    d(
      %{
        logger_pool_supervisor_name,
        sentiments_pool_supervisor_name,
        engagement_pool_supervisor_name,
        receiver_supervisor_name,
        counter_supervisor_name,
        statistic_supervisor_name,
        hashtag_supervisor_name,
        aggregator_supervisor_name,
        batcher_supervisor_name,
        db_service_supervisor_name
      }
    ) = supervisorsNames

    # Order meters

    # Statistics
    Logger.info("Starting a new Statistic worker")
    {:ok, statisticWorkerPID} = DynamicSupervisor.start_child(
      statistic_supervisor_name,
      {
        App.Statistic,
        args
      }
    )

    # Hashtags
    Logger.info("Starting a new Hashtag count actor")
    {:ok, hashtagWorkerPID} = DynamicSupervisor.start_child(
      hashtag_supervisor_name,
      {
        App.Hashtag,
        args
      }
    )

    # DB Service
    Logger.info("Starting a new DBService service")
    {:ok, dbServicePID} = DynamicSupervisor.start_child(
      db_service_supervisor_name,
      {
        App.DBService,
        Map.merge(args, d(%{statisticWorkerPID}))
      }
    )

    # Batcher
    Logger.info("Starting a new Batcher actor")
    {:ok, batcherPID} = DynamicSupervisor.start_child(
      batcher_supervisor_name,
      {
        App.Batcher,
        Map.merge(args, d(%{dbServicePID}))
      }
    )

    # Aggregator
    Logger.info("Starting a new Aggregator actor")
    {:ok, aggregatorPID} = DynamicSupervisor.start_child(
      aggregator_supervisor_name,
      {
        App.Aggregator,
        Map.merge(args, d(%{batcherPID}))
      }
    )

    # Sentiments worker pool
    sentimentWorkerArgs = Map.merge(args, d(%{aggregatorPID}))
    Logger.info("Starting a new Sentiments worker pool")
    {:ok, sentimentWorkerPoolPID} = DynamicSupervisor.start_child(
      sentiments_pool_supervisor_name,
      {
        WorkerPool,
        d(
          %{
            pool_supervisor_name: sentiments_pool_supervisor_name,
            worker: Worker.Sentiment,
            workerArgs: sentimentWorkerArgs,
          }
        )
      }
    )

    # Engagement worker pool
    engagementWorkerArgs = Map.merge(args, d(%{aggregatorPID}))
    Logger.info("Starting a new Engagement worker pool")
    {:ok, engagementWorkerPoolPID} = DynamicSupervisor.start_child(
      engagement_pool_supervisor_name,
      {
        WorkerPool,
        d(
          %{
            pool_supervisor_name: engagement_pool_supervisor_name,
            worker: Worker.Engagement,
            workerArgs: engagementWorkerArgs,
          }
        )
      }
    )

    # Logger worker Pool
    workerArgs = Map.merge(
      args,
      d(
        %{
          statisticWorkerPID,
          engagementWorkerPoolPID,
          sentimentWorkerPoolPID,
          hashtagWorkerPID
        }
      )
    )
    Logger.info("Starting a new Logger worker pool")
    {:ok, loggerWorkerPoolPID} = DynamicSupervisor.start_child(
      logger_pool_supervisor_name,
      {
        WorkerPool,
        d(
          %{
            pool_supervisor_name: logger_pool_supervisor_name,
            worker: Worker.Logger,
            workerArgs: workerArgs,
          }
        )
      }
    )

    # Counter for Receiver 1
    Logger.info("Starting a new Counter for current pools")
    {:ok, receiverCounterPID} = DynamicSupervisor.start_child(
      counter_supervisor_name,
      {
        App.Counter,
        Map.merge(args, %{workerPoolPIDs: [loggerWorkerPoolPID, sentimentWorkerPoolPID, engagementWorkerPoolPID]})
      }
    )

    # Receiver for first endpoint
    Logger.info("Starting a new Receiver for #{receiver_supervisor_name}")
    DynamicSupervisor.start_child(
      receiver_supervisor_name,
      {
        App.Receiver,
        d(
          %{
            loggerWorkerPoolPID,
            url: "#{@sse_base_url}/#{index}",
            counterPID: receiverCounterPID
          }
        )
      }
    )

  end

  ## Callbacks

  @impl true
  def init(args) do

    # because we have 2 SSE streams, we will start 2 similar "tree" structure
    children
    = Enum.map(
        1..2,
        fn index ->
          logger_pool_supervisor_name = String.to_atom(
            "LoggerPoolSupervisor_#{Kernel.inspect(args.socket)}_#{index}"
          )
          sentiments_pool_supervisor_name = String.to_atom(
            "SentimentsPoolSupervisor_#{Kernel.inspect(args.socket)}_#{index}"
          )
          engagement_pool_supervisor_name = String.to_atom(
            "EngagementPoolSupervisor_#{Kernel.inspect(args.socket)}_#{index}"
          )
          receiver_supervisor_name = String.to_atom(
            "ReceiverSupervisor_#{Kernel.inspect(args.socket)}_#{index}"
          )
          counter_supervisor_name = String.to_atom(
            "CounterSupervisor_#{Kernel.inspect(args.socket)}_#{index}"
          )
          statistic_supervisor_name = String.to_atom(
            "StatisticSupervisor_#{Kernel.inspect(args.socket)}_#{index}"
          )
          hashtag_supervisor_name = String.to_atom(
            "HashtagSupervisor_#{Kernel.inspect(args.socket)}_#{index}"
          )
          aggregator_supervisor_name = String.to_atom(
            "AggregatorSupervisor_#{Kernel.inspect(args.socket)}_#{index}"
          )
          batcher_supervisor_name = String.to_atom(
            "BatcherSupervisor_#{Kernel.inspect(args.socket)}_#{index}"
          )
          db_service_supervisor_name = String.to_atom(
            "DBServiceSupervisor_#{Kernel.inspect(args.socket)}_#{index}"
          )

          children = [
            {DynamicSupervisor, name: db_service_supervisor_name, strategy: :one_for_one},
            {DynamicSupervisor, name: batcher_supervisor_name, strategy: :one_for_one},
            {DynamicSupervisor, name: aggregator_supervisor_name, strategy: :one_for_one},
            {DynamicSupervisor, name: statistic_supervisor_name, strategy: :one_for_one},
            {DynamicSupervisor, name: hashtag_supervisor_name, strategy: :one_for_one},
            {DynamicSupervisor, name: counter_supervisor_name, strategy: :one_for_one},
            {DynamicSupervisor, name: receiver_supervisor_name, strategy: :one_for_one},
            {DynamicSupervisor, name: logger_pool_supervisor_name, strategy: :one_for_one},
            {DynamicSupervisor, name: sentiments_pool_supervisor_name, strategy: :one_for_one},
            {DynamicSupervisor, name: engagement_pool_supervisor_name, strategy: :one_for_one}
          ]

          # start processing tweets after delay
          spawn(
            fn ->
              Process.sleep(@ms_delay)
              supervisorsNames = d(
                %{
                  logger_pool_supervisor_name,
                  sentiments_pool_supervisor_name,
                  engagement_pool_supervisor_name,
                  receiver_supervisor_name,
                  counter_supervisor_name,
                  statistic_supervisor_name,
                  hashtag_supervisor_name,
                  aggregator_supervisor_name,
                  batcher_supervisor_name,
                  db_service_supervisor_name
                }
              )
              start_stream(args, supervisorsNames, index)
            end
          )

          children
        end
      ) # it will be an array of 2 lists, I need a flat one sentimental array
      |> Enum.reduce(
           [],
           fn arr, acc ->
             acc ++ arr
           end
         )

    Supervisor.init(children, strategy: :one_for_one)
  end

end