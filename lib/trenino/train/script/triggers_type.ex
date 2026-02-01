defmodule Trenino.Train.Script.TriggersType do
  @moduledoc """
  Custom Ecto type that stores a list of strings as a JSON-encoded string.

  Used for the `triggers` field in `Trenino.Train.Script` because SQLite
  doesn't have a native array type.
  """

  use Ecto.Type

  @impl true
  def type, do: :string

  @impl true
  def cast(value) when is_list(value) do
    if Enum.all?(value, &is_binary/1) do
      {:ok, value}
    else
      :error
    end
  end

  def cast(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, list} when is_list(list) -> {:ok, list}
      _ -> :error
    end
  end

  def cast(_), do: :error

  @impl true
  def dump(value) when is_list(value) do
    {:ok, Jason.encode!(value)}
  end

  def dump(_), do: :error

  @impl true
  def load(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, list} when is_list(list) -> {:ok, list}
      _ -> {:ok, []}
    end
  end

  def load(nil), do: {:ok, []}
  def load(_), do: :error
end
