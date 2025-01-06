defmodule ForkCleaner do
  @moduledoc """
  Documentation for `ForkCleaner`.
  """
  alias Tentacat.Repositories
  alias Tentacat.Search
  alias Tentacat.Users

  @red "\e[31m"
  @green "\e[32m"
  @yellow "\e[33m"
  @reset "\e[0m"

  def clean_forks() do
    access_token = Application.get_env(:fork_cleaner, :github_token)
    host = Application.get_env(:fork_cleaner, :github_host)

    client = Tentacat.Client.new(%{access_token: access_token}, host)

    pulls_task =
      Task.async(fn ->
        get_user_pull_requests(client)
      end)

    forks_task =
      Task.async(fn ->
        get_forks(client)
      end)

    forks = Task.await(forks_task)
    pulls = Task.await(pulls_task) |> MapSet.new()

    Enum.filter(forks, fn {owner, repo} ->
      if not MapSet.member?(pulls, {owner, repo}) do
        true
      else
        IO.puts("#{@yellow}Skipping #{owner}/#{repo} because it has open pull requests#{@reset}")
        false
      end
    end)

    IO.puts("\nYou have #{@green}#{length(forks)}#{@reset} forks to consider deleting:")

    forks
    |> Enum.map(fn {owner, repo} ->
      IO.puts("#{@yellow}#{owner}/#{repo}#{@reset}")
      {owner, repo}
    end)
    |> Enum.each(fn {owner, repo} ->
      IO.puts(
        "\nDo you want to delete #{@yellow}#{owner}/#{repo}#{@reset}? (#{@green}y#{@reset}/#{@red}n#{@reset})"
      )

      input = IO.gets("") |> String.trim()

      if input == "y" do
        IO.puts("\nDeleting #{@yellow}#{owner}/#{repo}#{@reset}...\n")

        case delete_fork(client, {owner, repo}) do
          {:ok} ->
            IO.puts("#{@green}Deleted fork#{@reset}!\n")

          {:error} ->
            IO.puts("#{@red}Failed to delete fork#{@reset}.\n")
        end
      end
    end)
  end

  defp get_forks(client) do
    case Repositories.list_mine(client) do
      {200, repos, _} ->
        repos
        |> Enum.filter(fn repo -> repo["fork"] end)
        |> Enum.map(fn repo ->
          String.split(repo["full_name"], "/")
          |> List.to_tuple()
        end)

      _ ->
        IO.puts("Failed to fetch repositories")
    end
  end

  defp get_username(client) do
    case Users.me(client) do
      {200, info, _} ->
        info["login"]

      _ ->
        IO.puts("Failed to fetch user info")
    end
  end

  defp get_user_pull_requests(client) do
    user = get_username(client)

    case Search.issues(client, q: "state:open type:pr author:#{user}", sort: "created") do
      {200, pulls, _} ->
        Enum.map(pulls["items"], fn pull ->
          get_repo_owner_from_url(pull["repository_url"])
        end)

      _ ->
        IO.puts("Failed to fetch pull requests")
    end
  end

  defp delete_fork(client, {owner, repo}) do
    {:ok}
    # case Repositories.delete(client, owner, repo) do
    #   {204, _, _} -> {:ok}
    #   _ -> {:error}
    # end
  end

  defp get_repo_owner_from_url(url) do
    String.split(url, "/")
    |> Enum.take(-2)
    |> List.to_tuple()
  end
end
