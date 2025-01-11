defmodule ForkCleaner do
  @red "\e[31m"
  @green "\e[32m"
  @yellow "\e[33m"
  @blue "\e[34m"
  @orange "\e[38;5;208m"
  @reset "\e[0m"
  @hyperlink_start "\e]8;;"
  @url_end "\e\\"
  @hyperlink_end @hyperlink_start <> @url_end

  def main(_args \\ []) do
    clean()
  end

  def clean() do
    client = get_client()

    client
    |> Fork.get_forks()
    |> print_forks()
    |> Enum.each(fn fork ->
      fork
      |> Fork.with_metadata(client)
      |> handle_fork_decision(client)
    end)
  end

  defp get_client() do
    access_token = Application.get_env(:fork_cleaner, :github_token)
    host = Application.get_env(:fork_cleaner, :github_host)
    Tentacat.Client.new(%{access_token: access_token}, host)
  end

  defp print_forks(forks) do
    IO.puts("You have #{color(Integer.to_string(length(forks)), @green)} total forks:")

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
         },
         client
       ) do
    IO.puts("""
    CONSIDERING #{color_link(link, repo, @yellow)} FOR DELETION

    Upstream repo: #{color_link(parent.link, parent.owner_repo, @blue)}
    """)

    if length(parent.pulls) > 0 do
      IO.puts("\n#{color("DANGER! You have open pull requests to the upstream repo!", @red)}\n")
      print_pull_list(parent.pulls, @red)
    else
      IO.puts("#{color("No open pull requests to the upstream repo ✓", @green)}")
    end

    IO.puts("""
    \nFork Stats:
    Open Issue Count: #{color(Integer.to_string(issue_count), count_color(issue_count))}
    Open Pull Request Count: #{color(Integer.to_string(length(pulls)), count_color(length(pulls)))}
    """)

    if length(pulls) > 0 do
      print_pull_list(pulls, @orange)
    end

    IO.puts("\nDo you want to delete #{color(repo)}? (#{color("y", @green)}/#{color("n", @red)})")

    input = IO.gets("") |> String.trim()

    if input == "y" do
      IO.puts("\nDeleting #{color(repo)}...\n")

      case Fork.delete_fork(repo, client) do
        {:ok} ->
          IO.puts("\n#{color("Deleted fork", @green)}!\n")

        {:error} ->
          IO.puts("\n#{color("Failed to delete fork", @red)}!\n")
      end
    else
      IO.puts("\n#{color("Skipping fork deletion", @red)}\n")
    end
  end

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
