defmodule Trenino.Firmware.Compatibility do
  @moduledoc """
  Decides whether a firmware release is compatible with the running app.

  Compatibility is determined by a single config key, parsed as an Elixir
  `Version.Requirement`:

      config :trenino, :firmware_version_requirement, "~> 1.0"

  When the key is unset (nil), all releases with a parseable semver
  version are considered compatible. Releases with malformed versions
  are always considered incompatible — we'd rather block a flash than
  silently install something we can't reason about.
  """

  alias Trenino.Firmware.FirmwareRelease

  @doc """
  Returns the parsed requirement, or `nil` if none is configured.

  Raises `Version.InvalidRequirementError` if the configured value is a
  binary that does not parse as a valid requirement string. Raises
  `ArgumentError` if the configured value is neither a binary nor `nil`.
  Misconfiguration is a developer bug, not a user-facing error.
  """
  @spec requirement() :: Version.Requirement.t() | nil
  def requirement do
    case Application.get_env(:trenino, :firmware_version_requirement) do
      nil ->
        nil

      string when is_binary(string) ->
        Version.parse_requirement!(string)

      other ->
        raise ArgumentError,
              "expected :firmware_version_requirement to be a binary or nil, got: #{inspect(other)}"
    end
  end

  @doc """
  Returns true if the given release (or version string) satisfies the
  configured requirement.

  - `nil` requirement → compatible iff the version itself is parseable.
  - Unparseable version → false.
  - `nil` version → false.
  """
  @spec compatible?(FirmwareRelease.t() | String.t() | nil) :: boolean()
  def compatible?(%FirmwareRelease{version: version}), do: compatible?(version)
  def compatible?(nil), do: false

  def compatible?(version) when is_binary(version) do
    case parse_version(version) do
      {:ok, parsed} ->
        case requirement() do
          nil -> true
          req -> Version.match?(parsed, req, allow_pre: false)
        end

      :error ->
        false
    end
  end

  defp parse_version("v" <> rest), do: parse_version(rest)
  defp parse_version(string), do: Version.parse(string)
end
