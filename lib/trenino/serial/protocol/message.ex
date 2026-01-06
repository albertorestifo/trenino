defmodule Trenino.Serial.Protocol.Message do
  @moduledoc """
  A shared protocol for communicating with the device over serial.
  """

  @type t() :: struct()

  @doc """
  Return the byte identifier for the message type.
  """
  @callback type() :: byte()

  @doc """
  Encode the message into a binary.
  Returns `{:ok, binary}` if successful, `{:error, reason}` otherwise.
  """
  @callback encode(t()) :: {:ok, binary()} | {:error, any()}

  @doc """
  Decode a binary into a message of type `t()`.
  Returns `{:ok, message}` if successful, `{:error, reason}` otherwise.
  """
  @callback decode(binary()) :: {:ok, t()} | {:error, any()}

  @registry_key {__MODULE__, :message_registry}

  @doc """
  Decode a binary into the corresponding message struct by examining the first byte.

  Returns `{:ok, message}` if successful, `{:error, reason}` otherwise.
  """
  @spec decode(binary()) :: {:ok, struct()} | {:error, any()}
  def decode(binary) when is_binary(binary) do
    if byte_size(binary) < 1 do
      {:error, :insufficient_data}
    else
      <<message_type, _::binary>> = binary
      registry = get_registry()

      case Map.get(registry, message_type) do
        nil ->
          {:error, :unknown_message_type}

        module ->
          module.decode(binary)
      end
    end
  end

  def decode(_), do: {:error, :invalid_input}

  # Get or build the registry, caching it in persistent_term for efficiency
  defp get_registry do
    case :persistent_term.get(@registry_key, nil) do
      nil ->
        registry = build_registry()
        :persistent_term.put(@registry_key, registry)
        registry

      registry ->
        registry
    end
  end

  # Build registry by discovering modules that implement the Message behaviour
  defp build_registry do
    case :application.get_key(:trenino, :modules) do
      {:ok, modules} ->
        modules
        |> Enum.filter(fn module ->
          # Check if module implements this behaviour
          # Note: :behaviour (singular) is the Erlang attribute name
          try do
            behaviours = module.module_info(:attributes)[:behaviour] || []
            __MODULE__ in behaviours
          rescue
            _ -> false
          end
        end)
        |> Enum.map(fn module ->
          try do
            type = module.type()
            {type, module}
          rescue
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Map.new()

      _ ->
        %{}
    end
  end
end
