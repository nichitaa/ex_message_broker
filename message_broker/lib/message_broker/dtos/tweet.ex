defmodule TweetDto do
  @derive [Poison.Encoder]
  defstruct [:id_str, :msg]
end
