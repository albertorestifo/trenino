defmodule Trenino.SerialSafetyCase do
  @moduledoc """
  Test case template for plain ExUnit.Case files that exercise serial /
  avrdude / discovery code paths but do not need the database sandbox.

  Installs the same forbidden default Mimic stubs as DataCase so accidental
  hardware access raises loudly.
  """

  use ExUnit.CaseTemplate

  using opts do
    async = Keyword.get(opts, :async, true)

    quote do
      use ExUnit.Case, async: unquote(async)
      use Mimic
    end
  end

  setup do
    Trenino.DataCase.setup_forbidden_serial_stubs()
    :ok
  end
end
