defmodule Trenino.Hardware.ConfigId do
  @moduledoc """
  Generates unique, random configuration IDs within the i32 range.

  Configuration IDs are used to link physical devices to their stored
  configurations. They are random to avoid conflicts when devices are
  shared or transferred between users.

  The ID is constrained to positive i32 values (1 to 2,147,483,647) to
  ensure protocol compatibility.
  """

  import Ecto.Query

  alias Trenino.Repo
  alias Trenino.Hardware.Device

  @max_i32 2_147_483_647
  @min_id 1

  @doc """
  Generates a unique random configuration ID.

  Returns `{:ok, config_id}` where config_id is a random positive integer
  that doesn't conflict with existing IDs in the database.

  ## Examples

      iex> {:ok, id} = Trenino.Hardware.ConfigId.generate()
      iex> is_integer(id) and id > 0 and id <= 2_147_483_647
      true

  """
  @spec generate() :: {:ok, integer()}
  def generate do
    config_id = random_id()

    if exists?(config_id) do
      generate()
    else
      {:ok, config_id}
    end
  end

  @doc """
  Generates a random ID without checking for uniqueness.

  Useful for testing or when you'll handle uniqueness yourself.
  """
  @spec random_id() :: integer()
  def random_id do
    :rand.uniform(@max_i32 - @min_id + 1) + @min_id - 1
  end

  @doc """
  Checks if a configuration ID already exists in the database.
  """
  @spec exists?(integer()) :: boolean()
  def exists?(config_id) do
    Device
    |> where([d], d.config_id == ^config_id)
    |> Repo.exists?()
  end

  @doc """
  Validates that a value is a valid configuration ID.

  Returns `true` if the value is an integer within the valid range.
  """
  @spec valid?(term()) :: boolean()
  def valid?(value) when is_integer(value) and value >= @min_id and value <= @max_i32, do: true
  def valid?(_), do: false

  @doc """
  Parses a string into a configuration ID.

  Returns `{:ok, config_id}` if the string represents a valid integer
  within the i32 range, or `{:error, :invalid}` otherwise.
  """
  @spec parse(String.t()) :: {:ok, integer()} | {:error, :invalid}
  def parse(string) when is_binary(string) do
    case Integer.parse(string) do
      {id, ""} when id >= @min_id and id <= @max_i32 -> {:ok, id}
      _ -> {:error, :invalid}
    end
  end

  def parse(_), do: {:error, :invalid}
end
