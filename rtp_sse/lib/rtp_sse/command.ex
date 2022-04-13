defmodule Command do

  import Destructure
  require Logger

  @mb_host Application.fetch_env!(:rtp_sse, :mb_host)
  @mb_port Application.fetch_env!(:rtp_sse, :mb_port)
  @port Application.fetch_env!(:rtp_sse, :port)
  @mb_delimiter Application.fetch_env!(:rtp_sse, :mb_delimiter)

  ## Client API

  def parse(line) do
    case String.trim(line, "\r\n") do
      "twitter" -> {:ok, {:twitter}}
      "mb" -> {:ok, {:mb}}
      data -> {:ok, {:other, data}}
    end
  end

  def run(command, socket)

  def run({:other, data}, socket) do
    Logger.info("Received #{inspect(data)}")
    {:ok, "[Command] run :other\r\n"}
  end

  def run({:mb}, socket) do
    case :gen_tcp.connect(@mb_host, @mb_port, [:binary, active: false]) do
      {:ok, mb_socket} ->
        # some tests
        serialized = "{\"id_str\":\"123123\",\"msg\":\"a simple text message\"}"
        publish = "PUBLISH tweets " <> serialized <> "\r\n"
        subscribe = "SUBSCRIBE tweets" <> "\r\n"
        ok = :gen_tcp.send(mb_socket, publish)
        # blocking
        r = :gen_tcp.recv(mb_socket, 0, @port)
        Logger.info("receive r: #{inspect(r)}")
      {:error, reason} ->
        Logger.info("Error: failed to connect to MessageBroker, reason: #{inspect(reason)}")
    end
    {:ok, "[Command] run :mb\r\n"}
  end

  def run({:twitter}, socket) do
    DynamicSupervisor.start_child(
      MainDynamicSupervisor,
      {
        MainSupervisor,
        d(%{socket})
      }
    )
    {:ok, "[Command] run :twitter\r\n"}
  end

end
