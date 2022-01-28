defmodule RTP_SSE.ReceiverWorker do
  use GenServer
  require Logger

  ## Client API

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

  ## Private

  defp loop_receive(socket) do
    receive do
      tweet ->
        msg = parse_tweet(tweet.data)

        if msg != nil do
          RTP_SSE.Server.notify(socket, msg)
        end

        loop_receive(socket)
    end
  end

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
    {socket, url} = state
    EventsourceEx.new(url, stream_to: self())
    loop_receive(socket)
    {:noreply, state}
  end
end
