defmodule Trenino.Serial.Protocol.StepperCommand do
  @moduledoc "Strict firmware 3.1.0 stepper command codec."
  @behaviour Trenino.Serial.Protocol.Message
  alias Trenino.Serial.Protocol.StepperConfiguration
  @type t :: %__MODULE__{}
  defstruct [:operation, :axis, :request_id, :configuration, :position]

  @operations [
    :configure,
    :move_to,
    :home,
    :stop,
    :enable,
    :release,
    :get_status,
    :keep_alive,
    :reset,
    :reference,
    :forget_driver
  ]
  @modes [:x27_six_state, :full_step, :half_step]

  @impl true
  def encode(%__MODULE__{} = m) do
    with true <- valid_header?(m), {:ok, payload} <- payload(m) do
      {:ok,
       <<16, 1, operation_id(m.operation), m.axis, m.request_id::little-16, payload::binary>>}
    else
      _ -> {:error, :invalid_stepper_command}
    end
  end

  defp valid_header?(m) do
    m.operation in @operations and is_integer(m.request_id) and m.request_id in 0..65_535 and
      (m.request_id != 0 or m.operation in [:get_status, :keep_alive]) and
      if(m.operation in [:keep_alive, :reset, :forget_driver],
        do: m.axis == 255,
        else: m.axis in [0, 1]
      )
  end

  defp payload(%__MODULE__{operation: :configure, configuration: %StepperConfiguration{} = c}) do
    if StepperConfiguration.valid?(c) do
      {:ok,
       <<1, Enum.find_index(@modes, &(&1 == c.mode)) + 1, c.shield_address, c.motor_port,
         flag(c.reverse), flag(c.idle_behavior == :hold), flag(c.host_loss_behavior == :hold),
         flag(c.reference_strategy == :internal_stop), c.min_position::little-signed-32,
         c.max_position::little-signed-32, c.max_speed::little-16, c.acceleration::little-16,
         c.home_direction::signed-8, c.home_steps::little-16, c.home_speed::little-16,
         c.home_timeout_ms::little-16, c.home_position::little-signed-32,
         c.watchdog_ms::little-16, c.home_backoff::little-16>>}
    else
      {:error, :invalid_configuration}
    end
  end

  defp payload(%__MODULE__{operation: op, position: p})
       when op in [:move_to, :reference] and is_integer(p) and p in -1_000_000..1_000_000,
       do: {:ok, <<p::little-signed-32>>}

  defp payload(%__MODULE__{operation: op}) when op not in [:configure, :move_to, :reference],
    do: {:ok, <<>>}

  defp payload(_), do: {:error, :invalid_payload}

  @impl true
  def decode_body(<<1, op, axis, id::little-16, rest::binary>>) when op <= 10 do
    m = %__MODULE__{operation: Enum.at(@operations, op), axis: axis, request_id: id}

    with {:ok, decoded} <- decode_payload(m, rest),
         {:ok, _} <- encode(decoded),
         do: {:ok, decoded}
  end

  def decode_body(_), do: {:error, :invalid_stepper_command}

  defp decode_payload(
         %__MODULE__{operation: :configure} = m,
         <<1, mode, address, port, reverse, idle, loss, strategy, min::little-signed-32,
           max::little-signed-32, speed::little-16, accel::little-16, direction::signed-8,
           steps::little-16, home_speed::little-16, timeout::little-16,
           position::little-signed-32, watchdog::little-16, backoff::little-16>>
       )
       when mode in 1..3 and reverse in 0..1 and idle in 0..1 and loss in 0..1 and
              strategy in 0..1 do
    {:ok,
     %{
       m
       | configuration: %StepperConfiguration{
           mode: Enum.at(@modes, mode - 1),
           shield_address: address,
           motor_port: port,
           reverse: reverse == 1,
           idle_behavior: behavior(idle),
           host_loss_behavior: behavior(loss),
           reference_strategy: if(strategy == 1, do: :internal_stop, else: :host_reference),
           min_position: min,
           max_position: max,
           max_speed: speed,
           acceleration: accel,
           home_direction: direction,
           home_steps: steps,
           home_speed: home_speed,
           home_timeout_ms: timeout,
           home_position: position,
           watchdog_ms: watchdog,
           home_backoff: backoff
         }
     }}
  end

  defp decode_payload(%__MODULE__{operation: op} = m, <<p::little-signed-32>>)
       when op in [:move_to, :reference], do: {:ok, %{m | position: p}}

  defp decode_payload(%__MODULE__{operation: op} = m, <<>>)
       when op not in [:configure, :move_to, :reference], do: {:ok, m}

  defp decode_payload(_, _), do: {:error, :invalid_payload}
  defp flag(true), do: 1
  defp flag(false), do: 0
  defp behavior(1), do: :hold
  defp behavior(0), do: :release
  def operation_id(op), do: Enum.find_index(@operations, &(&1 == op))
  def operation(id) when id in 0..10, do: Enum.at(@operations, id)
  def operation(_), do: nil
end
