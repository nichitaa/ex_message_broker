defmodule RTP_SSE.ReceiverWorker do
  use GenServer
  require Logger

  def start_link(opts) do
    Logger.info("[ReceiverWorker] start_link")
    state = parse_opts(opts)
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    {socket, _} = state
    Logger.info("[ReceiverWorker] init socket #{inspect(socket)}")

    # will invoke handle_info(:start_receiver_worker)
    Process.send_after(self(), :start_receiver_worker, 500)
    {:ok, state}
  end

  def parse_opts(opts) do
    socket = opts[:socket]
    url = opts[:url]
    {socket, url}
  end

  defp loop_receive(socket) do
    receive do
      tweet ->
        RTP_SSE.Server.notify(socket, tweet)
        loop_receive(socket)
    end
  end

  def handle_info(:start_receiver_worker, state) do
    {socket, url} = state
    EventsourceEx.new(url, stream_to: self())
    loop_receive(socket)
    {:noreply, state}
  end
end
