defmodule Mix.Tasks.VirtualJoystick do
  @shortdoc "Build the virtual joystick feeder sidecar"
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [debug: :boolean])
    mode = if opts[:debug], do: "debug", else: "release"
    sidecar_dir = Path.join([File.cwd!(), "tauri", "virtual_joystick"])

    unless File.dir?(sidecar_dir), do: Mix.raise("virtual joystick directory not found at #{sidecar_dir}")
    cargo_args = if mode == "debug", do: ["build"], else: ["build", "--release"]

    case System.cmd("cargo", cargo_args, cd: sidecar_dir, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        binary = if match?({:win32, _}, :os.type()), do: "virtual_joystick.exe", else: "virtual_joystick"
        Mix.shell().info(Path.join([sidecar_dir, "target", mode, binary]))
      {_, status} -> Mix.raise("Cargo build failed with exit code #{status}")
    end
  end
end
