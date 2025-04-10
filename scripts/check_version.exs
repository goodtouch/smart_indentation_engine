#!/usr/bin/env elixir

# check_version.exs
#
# SUMMARY
#
#   Checks that the versions in mix.exs and README.md are up-to-date

defmodule VersionChecker do
  def main do
    new_context(root_dir: File.cwd!())
    |> read_mix_file()
    |> compute_package_version_regex()
    |> get_latest_git_tag()
    |> compute_minimum_version()
    |> validate_mix_version!()
    |> check_readme_versions!()
    |> check_changelog_version!()
  end

  def new_context(opts) do
    %{
      root_dir: opts[:root_dir],
      package_name: nil,
      package_version_regex: nil,
      mix_version: nil,
      git_tag: nil,
      git_version: nil,
      commit_messages: nil,
      minimum_version: nil
    }
  end

  @doc """
  Sets `mix_version` and `package_name` from `mix.exs`
  """
  def read_mix_file(context) do
    {:ok, mix_exs_path} = Path.safe_relative("mix.exs", context.root_dir)
    mix_exs = File.read!(mix_exs_path)
    [_, mix_version_str] = Regex.run(~r/@version\s+"([^"]+)"/, mix_exs)
    [_, package_name] = Regex.run(~r/app: :(.+),/, mix_exs)
    mix_version = SemanticVersion.parse!(mix_version_str)

    %{context | mix_version: mix_version, package_name: package_name}
  end

  @doc """
  Computes a regexp that matches `{:package_name, "~> version"}`
  """
  def compute_package_version_regex(context) do
    package_version_regex =
      ~r/{\s*:#{Regex.escape(context.package_name)},\s*"~> (\d+\.\d+(?:\.\d+)*(?:-[0-9A-Za-z-.+]+)*)"}/

    %{context | package_version_regex: package_version_regex}
  end

  def get_latest_git_tag(context) do
    {git_tag, git_version} =
      case System.cmd("git", ["describe", "--tags", "--abbrev=0"], stderr_to_stdout: true) do
        {tag, 0} ->
          git_tag = String.trim(tag)
          git_version = git_tag |> String.replace_prefix("v", "") |> Version.parse!()
          {git_tag, git_version}

        {_, _} ->
          warn("no git tags available, defaulting to `mix.exs` version: `#{context.mix_version}`")
          {nil, nil}
      end

    %{context | git_tag: git_tag, git_version: git_version}
  end

  @doc """
  Infers the minimal required next version from the commit messages since the
  last git tag (according to conventional commit)
  """
  def compute_minimum_version(context)

  def compute_minimum_version(%{git_tag: nil} = context), do: %{context | minimum_version: context.mix_version}

  def compute_minimum_version(context) do
    {commit_log, 0} = System.cmd("git", ["log", "#{context.git_tag}..HEAD", "--pretty=format:%s"])
    commit_messages = String.split(commit_log, "\n", trim: true)

    minimum_version =
      commit_messages
      |> Enum.map(&SemanticVersion.after_conventional_commit(context.git_version, &1))
      |> max_or(context.git_version)

    IO.puts("Latest tagged version: #{SemanticVersion.to_string(context.git_version)}")
    IO.puts("Version in mix.exs: #{SemanticVersion.to_string(context.mix_version)}")
    IO.puts("Minimal required version in mix.exs: #{SemanticVersion.to_string(minimum_version)}")

    %{context | minimum_version: minimum_version}
  end

  defp max_or(list, default), do: Enum.max(list, &>=/2, fn -> default end)

  @doc """
  Reports an error if version in `mix.exs` is smaller than the minimum version
  """
  def validate_mix_version!(context) do
    if context.mix_version < context.minimum_version do
      error!("version in mix.exs is smaller than required")
    end

    context
  end

  @doc """
  Reports errors for examples in the `README.md` do not match the version in
  mix.exs
  """
  def check_readme_versions!(context) do
    {:ok, readme_path} = Path.safe_relative("README.md", context.root_dir)

    version_mismatch_statuses =
      readme_path
      |> File.stream!()
      |> Stream.map(&String.trim_trailing/1)
      |> Stream.with_index(1)
      |> Stream.filter(fn {line, _} -> String.match?(line, context.package_version_regex) end)
      |> Stream.flat_map(fn {line, line_num} -> parse_package_version(context, line, line_num) end)
      |> Stream.map(fn version -> report_if_version_mismatch(context, version, readme_path) end)
      |> Enum.to_list()

    if Enum.empty?(version_mismatch_statuses), do: warn("no version found in `README.md`")
    # (The list will contain one or more `true` values if there are any mismatches)
    if Enum.any?(version_mismatch_statuses), do: error!("`README.md` version does not match `mix.exs` version")

    success("`README.md` version matches `mix.exs` version")

    context
  end

  # Returns the parsed version + some metadata such as the position where we
  # matched in file, so that we can report a nice error using Elixir's
  # `Code.print_diagnostic\1`.
  defp parse_package_version(context, line, line_num) do
    for [matched_index] <-
          Regex.scan(context.package_version_regex, line, capture: :all_but_first, return: :index) do
      with {col_num, match_length} <- matched_index,
           matched_string <- byte_slice(line, matched_index),
           {:ok, {major, minor, patch, pre, build_parts}} <- Version.Parser.parse_version(matched_string, true) do
        # We use parse_version with `approximate? = true` so `patch` is optional
        # (i.e. when parsing `"~> 1.0"`). We `mix_version.patch` in that case so
        # we can check for equality later on.
        patch = patch || context.mix_version.patch
        build = if build_parts == [], do: nil, else: Enum.join(build_parts, ".")
        version = %Version{major: major, minor: minor, patch: patch, pre: pre, build: build}

        %{
          matched_string: matched_string,
          position: {line_num, col_num + 1},
          span: {line_num, col_num + 1 + match_length},
          version: version
        }
      else
        _other -> raise ~s(couldn't parse version in: "#{String.trim(line)}")
      end
    end
  end

  # Extracts a slice of the string using the byte offsets from a regex match
  defp byte_slice(string, index) do
    {start, length} = index
    String.byte_slice(string, start, length)
  end

  # Returns true if the version in README.md does not match the mix.exs version.
  # Also reports the error as a side effect.
  defp report_if_version_mismatch(context, match, file) do
    mismatch = match.version != context.mix_version

    if mismatch do
      error(%{
        severity: :error,
        message: "version `#{match.matched_string}` does not match mix version `#{context.mix_version}`",
        file: file,
        position: match.position,
        span: match.span
      })
    end

    mismatch
  end

  @doc """
  Reports an error if `CHANGELOG.md` does not contain a section for the current
  mix version
  """
  def check_changelog_version!(context) do
    {:ok, changelog_path} = Path.safe_relative("CHANGELOG.md", context.root_dir)

    if not File.exists?(changelog_path), do: error!("`CHANGELOG.md` file not found")

    changelog_content = File.read!(changelog_path)
    version_str = SemanticVersion.to_string(context.mix_version)
    version_section_pattern = ~r/## \[v#{Regex.escape(version_str)}\]/

    if String.match?(changelog_content, version_section_pattern) do
      success("`CHANGELOG.md` contains a section for version v#{version_str}")
    else
      error!("Version `v#{version_str}` does not have a dedicated section in `CHANGELOG.md`")
    end

    context
  end

  defp success(message) do
    IO.ANSI.format([:green, "success: ", :reset, message]) |> IO.puts()
  end

  defp warn(message) do
    IO.ANSI.format([:yellow, "warning: ", :reset, message]) |> IO.puts()
  end

  defp error(message) when is_binary(message) do
    IO.ANSI.format([:red, "error: ", :reset, message]) |> IO.puts()
  end

  defp error(diagnostic) when is_map(diagnostic) do
    IO.puts("")

    diagnostic
    |> Map.put(:severity, :error)
    |> Code.print_diagnostic()
  end

  defp error!(message) do
    error(message)
    System.halt(1)
  end
end

defmodule SemanticVersion do
  defdelegate parse!(string), to: Version
  defdelegate compare(v1, v2), to: Version
  defdelegate to_string(version), to: Version

  def increment(version, :major) do
    %Version{major: version.major + 1, minor: 0, patch: 0}
  end

  def increment(version, :minor) do
    %Version{major: version.major, minor: version.minor + 1, patch: 0}
  end

  def increment(version, :patch) do
    %Version{major: version.major, minor: version.minor, patch: version.patch + 1}
  end

  def after_conventional_commit(version, commit_message) do
    cond do
      String.contains?(commit_message, "!:") ->
        if version.major > 0 do
          increment(version, :major)
        else
          increment(version, :minor)
        end

      String.match?(commit_message, ~r/^feat/) ->
        increment(version, :minor)

      String.match?(commit_message, ~r/^(enhancement|fix|perf)/) ->
        increment(version, :patch)

      # chore, etc. -> no version bump
      true ->
        version
    end
  end
end

VersionChecker.main()
