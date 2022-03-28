defmodule StreamSupervisor do

  use Supervisor
  import Destructure
  require Logger

  @ss_delay Application.fetch_env!(:rtp_sse, :ss_delay)
  @sse_base_url Application.fetch_env!(:rtp_sse, :sse_base_url)

  @impl true
  def start_link(init_arg) do
    name = String.to_atom("StreamSupervisor_#{Kernel.inspect(init_arg.socket)}_#{init_arg.index}")
    Supervisor.start_link(__MODULE__, init_arg, name: name)
  end

  defp start_stream(args, supervisorsNames, index) do
    Logger.info("[StreamSupervisor] building tree for SSE stream no #{index}")
    stream_supervisor_name = String.to_atom("StreamSupervisor_#{Kernel.inspect(args.socket)}_#{args.index}")

    d(
      %{
        logger_pool_supervisor_name,
        sentiments_pool_supervisor_name,
        engagement_pool_supervisor_name
      }
    ) = supervisorsNames

    # Order meters

    stats_name = String.to_atom("Statistics_#{Kernel.inspect(args.socket)}_#{args.index}")

    # Statistics
    Logger.info("Starting a new Statistic worker")
    {:ok, statisticWorkerPID} = Supervisor.start_child(
      stream_supervisor_name,
      {App.Statistic, args}
    )

    # Hashtags
    Logger.info("Starting a new Hashtag count actor")
    {:ok, hashtagWorkerPID} = Supervisor.start_child(
      stream_supervisor_name,
      {App.Hashtag, args}
    )

    # DB Service
    Logger.info("Starting a new DBService service")
    {:ok, dbServicePID} = Supervisor.start_child(
      stream_supervisor_name,
      {
        App.DBService,
        Map.merge(args, d(%{statisticWorkerPID}))
      }
    )

    # Batcher
    Logger.info("Starting a new Batcher actor")
    {:ok, batcherPID} = Supervisor.start_child(
      stream_supervisor_name,
      {App.Batcher, Map.merge(args, d(%{dbServicePID}))}
    )

    # Aggregator
    Logger.info("Starting a new Aggregator actor")
    {:ok, aggregatorPID} = Supervisor.start_child(
      stream_supervisor_name,
      {App.Aggregator, Map.merge(args, d(%{batcherPID}))}
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
    {:ok, receiverCounterPID} = Supervisor.start_child(
      stream_supervisor_name,
      {
        App.Counter,
        Map.merge(args, %{workerPoolPIDs: [loggerWorkerPoolPID, sentimentWorkerPoolPID, engagementWorkerPoolPID]})
      }
    )

    # Receiver for first endpoint
    Logger.info("Starting a new Receiver")
    Supervisor.start_child(
      stream_supervisor_name,
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

  @impl true
  def init(args) do
    d(%{socket, index}) = args
    logger_pool_supervisor_name = String.to_atom(
      "LoggerPoolSupervisor_#{Kernel.inspect(socket)}_#{index}"
    )
    sentiments_pool_supervisor_name = String.to_atom(
      "SentimentsPoolSupervisor_#{Kernel.inspect(socket)}_#{index}"
    )
    engagement_pool_supervisor_name = String.to_atom(
      "EngagementPoolSupervisor_#{Kernel.inspect(socket)}_#{index}"
    )

    children = [
      {DynamicSupervisor, name: logger_pool_supervisor_name, strategy: :one_for_one},
      {DynamicSupervisor, name: sentiments_pool_supervisor_name, strategy: :one_for_one},
      {DynamicSupervisor, name: engagement_pool_supervisor_name, strategy: :one_for_one}
    ]

    # start processing tweets after delay
    spawn(
      fn ->
        Process.sleep(@ss_delay)
        supervisorsNames = d(
          %{
            logger_pool_supervisor_name,
            sentiments_pool_supervisor_name,
            engagement_pool_supervisor_name
          }
        )
        start_stream(args, supervisorsNames, index)
      end
    )
    Supervisor.init(children, strategy: :one_for_one)
  end
end