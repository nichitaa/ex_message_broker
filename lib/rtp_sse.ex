defmodule RTP_SSE do
  @moduledoc ~S"""
  ### Compile the project and start a new `iex` session inside it
  
      > iex -S mix
  
  ### Start the builtin observer tool to inspect processes
  
      iex> :observer.start
  
  ### Connect via telnet client to the :gen_tcp server
  
      > telnet localhost 8080
  
  ### See the SSEs (tweets) with `twitter` command
  
      > `twitter`
  """
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("[Application] Start")

    children = [
      # Each LoggerRouter will dynamically start some LoggerWorkers
      # max_restarts: defaults to 3, meaning if in 5 seconds our dynamic supervisor will restart 3 child workers
      # then it will not start more child processes, in our use case the we have a lot of panic messages that
      # just constantly kills our workers !!
      {
        DynamicSupervisor,
        name: RTP_SSE.LoggerWorkerDynamicSupervisor,
        strategy: :one_for_one,
        max_restarts: 100
      },
      # Each client connection will start a LoggerRouter process
      {DynamicSupervisor, name: RTP_SSE.LoggerRouterDynamicSupervisor, strategy: :one_for_one},
      # Dynamic supervisor for the ReceiverWorker (handles sse for subscribers)
      {DynamicSupervisor, name: RTP_SSE.ReceiverWorkerDynamicSupervisor, strategy: :one_for_one},
      # Tweets counter supervisor, required for autoscaling the workers

      {DynamicSupervisor, name: RTP_SSE.TweetsCounterDynamicSupervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: RTP_SSE.StatisticWorkerDynamicSupervisor, strategy: :one_for_one},
      {RTP_SSE.HashtagsWorker, name: RTP_SSE.HashtagsWorker},
      {TweetProcessor.DBService, name: TweetProcessor.DBService},
      {TweetProcessor.Aggregator, name: TweetProcessor.Aggregator},
      # Server
      {Task.Supervisor, name: RTP_SSE.Server.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> RTP_SSE.Server.accept(8080) end}, restart: :permanent)
    ]

    opts = [strategy: :one_for_one, name: RTP_SSE.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
