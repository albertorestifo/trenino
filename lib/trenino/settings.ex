defmodule Trenino.Settings do
  @moduledoc """
  Public interface for application-wide preferences.

  Callers use atoms; conversion to/from the underlying string
  storage happens internally. Never exposes the underlying schema.
  """

  alias Trenino.Repo
  alias Trenino.Settings.Setting

  require Logger

  @error_reporting_key "error_reporting"
  @error_reporting_values [:enabled, :disabled]

  @spec error_reporting?() :: boolean()
  def error_reporting?, do: get_atom(@error_reporting_key, @error_reporting_values) == :enabled

  @spec error_reporting_set?() :: boolean()
  def error_reporting_set?, do: not is_nil(get_raw(@error_reporting_key))

  @spec set_error_reporting(:enabled | :disabled) ::
          {:ok, Setting.t()} | {:error, Ecto.Changeset.t()}
  def set_error_reporting(value) when value in @error_reporting_values do
    put_raw(@error_reporting_key, Atom.to_string(value))
  end

  @doc """
  Sentry `before_send` callback. Returns `false` to drop the event when the
  user has not opted in to error reporting; otherwise returns the event
  unchanged. Sentry treats a falsy return as "exclude" and a truthy return
  as "send".
  """
  @spec sentry_before_send(event) :: event | false when event: term()
  def sentry_before_send(event) do
    if error_reporting?(), do: event, else: false
  end

  # Private helpers

  defp get_raw(key) do
    case Repo.get(Setting, key) do
      nil -> nil
      %Setting{value: value} -> value
    end
  end

  defp get_atom(key, allowed) do
    case get_raw(key) do
      nil -> nil
      raw -> safe_to_atom(raw, allowed)
    end
  end

  defp safe_to_atom(raw, allowed) do
    atom = String.to_existing_atom(raw)
    if atom in allowed, do: atom
  rescue
    ArgumentError ->
      Logger.warning("Trenino.Settings: unknown value #{inspect(raw)} in app_settings, ignoring")
      nil
  end

  defp put_raw(key, value) do
    %Setting{}
    |> Setting.changeset(%{key: key, value: value})
    |> Repo.insert(
      on_conflict: [set: [value: value]],
      conflict_target: :key
    )
  end
end
