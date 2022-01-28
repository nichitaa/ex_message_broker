defmodule RTP_SSE.Command do
  require Logger

  def parse(line) do
    case String.trim(line, "\r\n") do
      "twitter" -> {:ok, {:twitter}}
      _ -> {:error, :unknown_command}
    end
  end

  def run(command, socket)

  def run({:twitter}, socket) do
    Logger.info("[Command] run :twitter - socket - #{inspect(socket)}")

    {:ok, "[Command] run :twitter\r\n"}
  end
end
