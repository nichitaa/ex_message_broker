defmodule RTP_SSE.ReceiverWorker do
  use GenServer
  require Logger

  ## Client API

  def start_link(opts) do
    state = parse_opts(opts)
    Logger.info("[ReceiverWorker] start_link - satate #{inspect(state)}")
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    {socket, _, _} = state
    Logger.info("[ReceiverWorker] init socket #{inspect(socket)}")

    # will invoke handle_info(:start_receiver_worker)
    Process.send_after(self(), :start_receiver_worker, 500)
    {:ok, state}
  end

  def parse_opts(opts) do
    socket = opts[:socket]
    url = opts[:url]
    routerPID = opts[:routerPID]
    {socket, url, routerPID}
  end

  ## Private

  defp loop_receive(socket, routerPID) do
    receive do
      tweet ->
        msg = parse_tweet(tweet.data)

        GenServer.cast(routerPID, {:route, msg})
        # RTP_SSE.Server.notify(socket, msg)

        loop_receive(socket, routerPID)
    end
  end

  # TODO: this validation must be on the worker level (LoggerWorker)
  defp parse_tweet(data) do
    if data == "{\"message\": panic}" do
      "[ReceiverWorker] ########################### GOT PANIC MESSAGE ###########################"
    else
      {:ok, json} = Poison.decode(data)
      json["message"]["tweet"]["text"]
    end
  end

  ## Callbacks

  def handle_info(:start_receiver_worker, state) do
    {socket, url, routerPID} = state
    EventsourceEx.new(url, stream_to: self())
    loop_receive(socket, routerPID)
    {:noreply, state}
  end
end
