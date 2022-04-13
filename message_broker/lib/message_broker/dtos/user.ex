defmodule UserDto do
  @derive [Poison.Encoder]
  defstruct [:id_str, :username]
end
