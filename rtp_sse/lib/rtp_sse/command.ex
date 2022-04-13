defmodule Command do

  import Destructure
  require Logger

  ## Client API

  def parse(line) do
    Logger.info("P-Server parse line #{inspect(line)}")
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
    Logger.info("received :mb command")

    case :gen_tcp.connect('localhost', 8000, [:binary, active: true]) do
      {:ok, mb_socket} ->
        ok = :gen_tcp.send(mb_socket, "something\r\n")
      {:error, reason} ->
        Logger.info("error on connecting to MB")
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
