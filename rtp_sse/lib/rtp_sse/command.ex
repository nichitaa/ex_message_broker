defmodule Command do

  import Destructure
  require Logger

  @mb_host Application.fetch_env!(:rtp_sse, :mb_host)
  @mb_port Application.fetch_env!(:rtp_sse, :mb_port)
  @port Application.fetch_env!(:rtp_sse, :port)

  ## Client API

  def parse(line) do
    case String.trim(line, "\r\n") do
      "twitter" -> {:ok, {:twitter}}
      data -> {:ok, {:other, data}}
    end
  end

  def run(command, socket)

  def run({:other, data}, socket) do
    Logger.info("Received #{inspect(data)}")
    {:ok, "[Command] run :other\r\n"}
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
