defmodule ForkCleaner do
  @moduledoc """
  A module for cleaning up forks on GitHub.

  This module is responsible for fetching forks from the GitHub API,
  and then cleaning them up by deleting them if they are no longer needed.

  It is designed to be run as an escript, and will prompt the user for confirmation
  before deleting any forks.

  ## Examples

  ```bash
  ./fork_cleaner --skip-with-upstream-prs
  ```

  ## Options

  - `:skip_with_upstream_prs`
    - Automatically skips forks with open pull requests to the upstream repo.
    - Defaults to `false`.

  """

  @red "\e[31m"
  @green "\e[32m"
  @yellow "\e[33m"
  @blue "\e[34m"
  @orange "\e[38;5;208m"
  @reset "\e[0m"
  @hyperlink_start "\e]8;;"
  @url_end "\e\\"
  @hyperlink_end @hyperlink_start <> @url_end

  def main(args \\ []) do
    options = parse_args(args)
    clean(options)
  end

  def clean(options \\ []) do
    client = get_client()

    client
    |> Fork.get_forks()
    |> print_forks()
    |> Enum.each(fn fork ->
      fork
      |> Fork.with_metadata(client)
      |> handle_fork_decision(client, options)
    end)

    IO.puts("\n#{color("Finished cleaning forks", @green)}\n")
  end

  defp parse_args(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [skip_with_upstream_prs: :boolean],
        aliases: [s: :skip_with_upstream_prs]
      )

    opts
  end

  defp get_client() do
    access_token = Application.get_env(:fork_cleaner, :github_token)
    host = Application.get_env(:fork_cleaner, :github_host)
    Tentacat.Client.new(%{access_token: access_token}, host)
  end

  defp print_forks(forks) do
    IO.puts("You have #{color(Integer.to_string(length(forks)), @green)} fork(s):")

    Enum.each(forks, fn fork ->
      IO.puts(" * " <> color_link(fork.link, fork.owner_repo, @yellow))
    end)

    IO.puts("\n")

    forks
  end

  defp handle_fork_decision(
         %Fork{
           owner_repo: repo,
           link: link,
           issue_count: issue_count,
           pulls: pulls,
           parent: parent
         } = fork,
         client,
         options
       ) do
    IO.puts("""
    ** CONSIDERING #{color_link(link, repo, @blue)} FOR DELETION **

    Upstream repo: #{color_link(parent.link, parent.owner_repo, @yellow)}

    Fork Stats:
    Open Issue Count: #{color(Integer.to_string(issue_count), count_color(issue_count))}
    Open Pull Request Count: #{color(Integer.to_string(length(pulls)), count_color(length(pulls)))}
    """)

    print_pull_list(pulls, @orange)

    case List.wrap(parent.pulls) do
      [] ->
        IO.puts("#{color("No open pull requests to the upstream repo ✓", @green)}")
        prompt_fork_deletion(fork, client)

      _ ->
        IO.puts("\n#{color("DANGER! You have open pull requests to the upstream repo!", @red)}\n")
        print_pull_list(parent.pulls, @red)

        if Keyword.get(options, :skip_with_upstream_prs, false) do
          IO.puts("\n#{color("Skipping fork deletion automatically", @orange)}\n")
        else
          prompt_fork_deletion(fork, client)
        end
    end
  end

  defp prompt_fork_deletion(%Fork{owner_repo: repo}, client) do
    IO.puts(
      "\nDo you want to delete #{color(repo, @blue)}? (#{color("y", @green)}/#{color("n", @red)})"
    )

    input = IO.gets("") |> String.trim()

    if input == "y" do
      IO.puts("\nDeleting #{color(repo)}...\n")

      case Fork.delete_fork(repo, client) do
        :ok ->
          IO.puts("\n#{color("Deleted fork", @green)}!\n")

        :error ->
          IO.puts("\n#{color("Failed to delete fork", @red)}!\n")
      end
    else
      IO.puts("\n#{color("Skipping fork deletion", @orange)}\n")
    end
  end

  defp print_pull_list([], _color), do: :ok

  defp print_pull_list(pulls, color) do
    Enum.each(pulls, fn {title, link} ->
      IO.puts(" * " <> color_link(link, title, color))
    end)
  end

  defp count_color(count) when count > 0, do: @orange
  defp count_color(_count), do: @green

  defp color_link(link, text, text_color),
    do: "#{@hyperlink_start}#{link}#{@url_end}#{color(text, text_color)}#{@hyperlink_end}"

  defp color({owner, repo}), do: "#{@yellow}#{owner}/#{repo}#{@reset}"

  defp color(input, text_color) when is_binary(input),
    do: "#{text_color}#{input}#{@reset}"

  defp color(input, text_color) when is_tuple(input),
    do: "#{text_color}#{Tuple.to_list(input) |> Enum.join("/")}#{@reset}"
end
