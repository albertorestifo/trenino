defmodule Mix.Tasks.Version do
  @shortdoc "Update version in all project files"
  @moduledoc """
  Updates the version string in all project files.

  ## Usage

      mix version 0.1.2
      mix version v0.1.2

  This will update the version in:
  - mix.exs
  - tauri/src-tauri/tauri.conf.json
  - tauri/src-tauri/Cargo.toml
  - tauri/package.json
  - tauri/src-tauri/splash.html

  The 'v' prefix is optional and will be stripped.

  ## Options

  - `--dry-run` - Show what would be changed without making changes
  """

  use Mix.Task

  @version_regex ~r/^[0-9]+\.[0-9]+\.[0-9]+$/

  @impl Mix.Task
  def run(args) do
    {opts, args, _} = OptionParser.parse(args, switches: [dry_run: :boolean])
    dry_run = Keyword.get(opts, :dry_run, false)

    case args do
      [version] ->
        version = String.trim_leading(version, "v")

        if Regex.match?(@version_regex, version) do
          update_version(version, dry_run)
        else
          Mix.shell().error("Error: Invalid version format '#{version}'. Expected format: X.Y.Z")
          exit({:shutdown, 1})
        end

      [] ->
        Mix.shell().error("Usage: mix version <version>")
        Mix.shell().error("Example: mix version 0.1.2")
        exit({:shutdown, 1})

      _ ->
        Mix.shell().error("Error: Too many arguments")
        Mix.shell().error("Usage: mix version <version>")
        exit({:shutdown, 1})
    end
  end

  defp update_version(version, dry_run) do
    if dry_run do
      Mix.shell().info("Dry run: would update all files to version #{version}")
    else
      Mix.shell().info("Updating all files to version #{version}")
    end

    project_root = File.cwd!()

    files = [
      {"mix.exs", &update_mix_exs/2},
      {"tauri/src-tauri/tauri.conf.json", &update_tauri_conf/2},
      {"tauri/src-tauri/Cargo.toml", &update_cargo_toml/2},
      {"tauri/package.json", &update_package_json/2},
      {"tauri/src-tauri/splash.html", &update_splash_html/2}
    ]

    results =
      Enum.map(files, fn {relative_path, updater} ->
        path = Path.join(project_root, relative_path)
        update_file(path, relative_path, version, updater, dry_run)
      end)

    if Enum.all?(results, & &1) do
      # Update Cargo.lock if cargo is available
      update_cargo_lock(project_root, dry_run)

      Mix.shell().info("")
      Mix.shell().info("Done! Version updated to #{version} in all files.")
      Mix.shell().info("")
      Mix.shell().info("Next steps:")
      Mix.shell().info("  1. Review changes: git diff")
      Mix.shell().info("  2. Commit: git add -A && git commit -m \"Bump version to #{version}\"")
      Mix.shell().info("  3. Tag: git tag v#{version}")
      Mix.shell().info("  4. Push: git push && git push --tags")
    else
      Mix.shell().error("Some files failed to update")
      exit({:shutdown, 1})
    end
  end

  defp update_file(path, relative_path, version, updater, dry_run) do
    if File.exists?(path) do
      content = File.read!(path)
      new_content = updater.(content, version)

      if content != new_content do
        Mix.shell().info("  - #{relative_path}")

        unless dry_run do
          File.write!(path, new_content)
        end

        true
      else
        Mix.shell().info("  - #{relative_path} (no change)")
        true
      end
    else
      Mix.shell().error("  - #{relative_path} (not found)")
      false
    end
  end

  defp update_mix_exs(content, version) do
    Regex.replace(
      ~r/version: "[0-9]+\.[0-9]+\.[0-9]+"/,
      content,
      "version: \"#{version}\""
    )
  end

  defp update_tauri_conf(content, version) do
    Regex.replace(
      ~r/"version": "[0-9]+\.[0-9]+\.[0-9]+"/,
      content,
      "\"version\": \"#{version}\""
    )
  end

  defp update_cargo_toml(content, version) do
    # Only update the package version line (at the start of line)
    Regex.replace(
      ~r/^version = "[0-9]+\.[0-9]+\.[0-9]+"/m,
      content,
      "version = \"#{version}\""
    )
  end

  defp update_package_json(content, version) do
    Regex.replace(
      ~r/"version": "[0-9]+\.[0-9]+\.[0-9]+"/,
      content,
      "\"version\": \"#{version}\""
    )
  end

  defp update_splash_html(content, version) do
    Regex.replace(
      ~r/>v[0-9]+\.[0-9]+\.[0-9]+</,
      content,
      ">v#{version}<"
    )
  end

  defp update_cargo_lock(project_root, dry_run) do
    cargo_dir = Path.join(project_root, "tauri/src-tauri")
    cargo_lock = Path.join(cargo_dir, "Cargo.lock")

    if File.exists?(cargo_lock) and cargo_available?() do
      Mix.shell().info("  - tauri/src-tauri/Cargo.lock (via cargo update)")

      unless dry_run do
        System.cmd("cargo", ["update", "--package", "trenino"],
          cd: cargo_dir,
          stderr_to_stdout: true
        )
      end
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
