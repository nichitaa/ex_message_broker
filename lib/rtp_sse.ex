defmodule RTP_SSE do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("[Application] start")
  end
end
