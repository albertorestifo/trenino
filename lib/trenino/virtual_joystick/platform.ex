defmodule Trenino.VirtualJoystick.Platform do
  @moduledoc false

  def windows?, do: match?({:win32, _}, :os.type())
end
