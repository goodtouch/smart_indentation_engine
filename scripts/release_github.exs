#!/usr/bin/env elixir

# release_github.exs
#
# SUMMARY
#
#   This script automates the process of creating a release on GitHub.

defmodule GitHubReleaser do
  def main do
    new_release(root_dir: File.cwd!())
    |> read_mix_metadata()
    |> compute_changelog_url()
    |> build_create_cmd()
    |> build_upload_cmd()
    |> create_github_release()
    |> upload_assets()
  end

  # Configuration for creating a GitHub release.
  def new_release(opts) do
    %{
      root_dir: opts[:root_dir],
      # the app name set in mix.exs
      package_name: nil,
      # the @version set in mix.exs
      version_str: nil,
      # the @github_url set in mix.exs
      github_url: nil,
      # the GitHub repo name, e.g. "elixir-lang/elixir"
      github_repo: nil,
      # the tag name, e.g. "v1.0.0"
      tag: nil,
      # the URL to the changelog entry
      changelog_url: nil,
      # the gh command to create the GitHub release
      create_cmd: nil,
      # the gh command to upload file assets to the GitHub release
      upload_cmd: nil
    }
  end

  # Read @version and @github_url from mix.exs
  def read_mix_metadata(release) do
    {:ok, mix_exs_path} = Path.safe_relative("mix.exs", release.root_dir)
    mix_exs = File.read!(mix_exs_path)

    [_, version_str] = Regex.run(~r/@version\s+"([^"]+)"/, mix_exs)
    [_, github_url] = Regex.run(~r/@github_url\s+"([^"]+)"/, mix_exs)
    [_, package_name] = Regex.run(~r/app: :(.+),/, mix_exs)
    github_repo = String.split(github_url, "/") |> Enum.take(-2) |> Enum.join("/")

    %{
      release
      | version_str: version_str,
        github_url: github_url,
        github_repo: github_repo,
        tag: "v#{version_str}",
        package_name: package_name
    }
  end

  # Get anchored URL to the changelog entry
  def compute_changelog_url(release) do
    {:ok, changelog_path} = Path.safe_relative("CHANGELOG.md", release.root_dir)

    if not File.exists?(changelog_path), do: error!("`CHANGELOG.md` file not found")

    changelog = File.read!(changelog_path)

    changelog_line =
      case Regex.run(~r/## \[v#{release.version_str}\] - .*/, changelog) do
        nil -> raise "Version v#{release.version_str} not found in CHANGELOG.md"
        [line] -> line
      end

    changelog_anchor =
      changelog_line
      |> String.replace("## ", "")
      |> String.replace(~r/[\[\].]/, "")
      |> String.replace(" ", "-")

    %{release | changelog_url: "#{release.github_url}/blob/main/CHANGELOG.md##{changelog_anchor}"}
  end

  # Build the gh command to create a GitHub release
  def build_create_cmd(release) do
    cmd = [
      ["gh", "release"],
      ["create", release.tag],
      ["--title", release.tag],
      ["--notes", "[View CHANGELOG for #{release.tag}](#{release.changelog_url})"],
      ["--repo", release.github_repo],
      ["--verify-tag"]
    ]

    %{release | create_cmd: cmd}
  end

  # Build the gh command to upload file assets to the GitHub release
  def build_upload_cmd(release) do
    archive =
      Path.wildcard("#{release.root_dir}/pkg/*-#{release.version_str}.tar")
      |> Enum.map(&Path.basename/1)
      |> List.first()

    if is_nil(archive) do
      IO.puts("Release not found for version #{release.version_str}")
      IO.puts("Make sure to run `make release.build` before this script")
      System.halt(1)
    end

    cmd = [
      ["gh", "release"],
      ["upload", release.tag],
      ["pkg/*-#{release.version_str}.tar"],
      ["--repo", release.github_repo],
      ["--clobber"]
    ]

    %{release | upload_cmd: cmd}
  end

  def format_cmd(cmd) do
    cmd
    |> Enum.map(fn
      [a, b] -> "#{a} #{b}"
      [a] -> a
    end)
    |> Enum.join(" \\\n  ")
  end

  def create_github_release(%{create_cmd: create_cmd} = release) do
    [cmd | args] = List.flatten(create_cmd)

    # Execute the command
    {output, status} = System.cmd(cmd, args, stderr_to_stdout: true)

    if status == 0 do
      success("GitHub release v#{release.version_str} created!")
      IO.puts("Changelog URL: #{release.changelog_url}")
    else
      pretty_cmd =
        create_cmd
        |> format_cmd()
        |> String.replace(~r/(\[.+\]\(.+\))/, "'\\1'")

      error!("""
      failed to create release:

      #{output |> String.trim()}

      while running:

      #{pretty_cmd}
      """)
    end

    release
  end

  def upload_assets(%{upload_cmd: update_cmd} = release) do
    [cmd | args] = List.flatten(update_cmd)

    # Execute the command
    {output, status} = System.cmd(cmd, args, stderr_to_stdout: true)

    if status == 0 do
      success("uploaded release to GitHub")
    else
      pretty_cmd = update_cmd |> format_cmd()

      error!("""
      failed to upload assets to GitHub:

      #{output |> String.trim()}

      while running:

      #{pretty_cmd}
      """)
    end

    release
  end

  defp success(message) do
    IO.ANSI.format([:green, "success: ", :reset, message]) |> IO.puts()
  end

  defp error(message) when is_binary(message) do
    IO.ANSI.format([:red, "error: ", :reset, message]) |> IO.puts()
  end

  defp error!(message) do
    error(message)
    System.halt(1)
  end
end

GitHubReleaser.main()
