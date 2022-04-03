defmodule Command do

  import Destructure
  require Logger

  ## Client API

  def parse(line) do
    case String.trim(line, "\r\n") do
      "twitter" -> {:ok, {:twitter}}
      _ -> {:error, :unknown_command}
    end
  end

  def run(command, socket)

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
