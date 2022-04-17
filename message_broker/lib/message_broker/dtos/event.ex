defmodule EventDto do
  @moduledoc """
  Generic event DTO for all incoming messages from our producers
  """
  @derive [Poison.Encoder]
  defstruct [:id, :msg, :priority]
end
