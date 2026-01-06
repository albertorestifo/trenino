defmodule Mix.Tasks.Keystroke do
  @shortdoc "Build the keystroke utility for local development"
  @moduledoc """
  Builds the keystroke utility for local development.

  The keystroke utility is a Rust executable that simulates keyboard input.
  It's used when button bindings are configured in "keystroke" mode.

  ## Usage

      mix keystroke

  This will:
  1. Build the keystroke utility using Cargo (release mode)
  2. The binary will be placed in `tauri/keystroke/target/release/`

  The `Trenino.Keyboard` module automatically detects this location when
  running with `mix phx.server`.

  ## Options

  - `--debug` - Build in debug mode (faster compilation, slower runtime)

  ## Prerequisites

  - Rust toolchain (install via https://rustup.rs/)
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [debug: :boolean])
    debug_mode = Keyword.get(opts, :debug, false)

    project_root = File.cwd!()
    keystroke_dir = Path.join([project_root, "tauri", "keystroke"])

    unless File.exists?(keystroke_dir) do
      Mix.shell().error("Error: keystroke directory not found at #{keystroke_dir}")
      exit({:shutdown, 1})
    end

    unless cargo_available?() do
      Mix.shell().error("Error: Cargo not found. Install Rust from https://rustup.rs/")
      exit({:shutdown, 1})
    end

    build_mode = if debug_mode, do: "debug", else: "release"
    Mix.shell().info("Building keystroke utility (#{build_mode} mode)...")

    cargo_args = if debug_mode, do: ["build"], else: ["build", "--release"]

    case System.cmd("cargo", cargo_args, cd: keystroke_dir, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        binary_name = if match?({:win32, _}, :os.type()), do: "keystroke.exe", else: "keystroke"
        binary_path = Path.join([keystroke_dir, "target", build_mode, binary_name])

        Mix.shell().info("")
        Mix.shell().info("Success! Built: #{binary_path}")
        Mix.shell().info("")
        Mix.shell().info("The keystroke utility is now available for local development.")
        Mix.shell().info("Verify with: iex -S mix -e 'IO.inspect(Trenino.Keyboard.available?())'")

      {_, exit_code} ->
        Mix.shell().error("Cargo build failed with exit code #{exit_code}")
        exit({:shutdown, exit_code})
    end
  end

  defp cargo_available? do
    case System.cmd("cargo", ["--version"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end
end
