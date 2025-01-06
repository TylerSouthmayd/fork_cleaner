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

  def main(args \\ []) do
    clean_forks()
  end

  def clean_forks() do
    access_token = Application.get_env(:fork_cleaner, :github_token)
    host = Application.get_env(:fork_cleaner, :github_host)

    client = Tentacat.Client.new(%{access_token: access_token}, host)

    forks_task =
      Task.async(fn ->
        get_forks(client)
      end)

    pulls =
      get_user_pull_requests(client)
      |> MapSet.new()

    forks =
      Task.await(forks_task)
      |> Enum.filter(fn {owner, repo} ->
        if not MapSet.member?(pulls, {owner, repo}) do
          true
        else
          IO.puts(
            "#{color("Skipping #{owner}/#{repo} because it has open pull requests", @yellow)}"
          )

          false
        end
      end)

    IO.puts(
      "\nYou have #{color(Integer.to_string(length(forks)), @green)} forks to consider deleting:"
    )

    forks
    |> Enum.map(fn {owner, repo} ->
      IO.puts(color({owner, repo}))
      {owner, repo}
    end)
    |> Enum.each(fn {owner, repo} ->
      IO.puts(
        "\nDo you want to delete #{color({owner, repo})}? (#{color("y", @green)}/#{color("n", @red)})"
      )

      input = IO.gets("") |> String.trim()

      if input == "y" do
        IO.puts("\nDeleting #{color({owner, repo})}...\n")

        case delete_fork(client, {owner, repo}) do
          {:ok} ->
            IO.puts("#{color("Deleted fork", @green)}!\n")

          {:error} ->
            IO.puts("#{color("Failed to delete fork", @red)}!\n")
        end
      end
    end)
  end

  defp color({owner, repo}), do: color("#{owner}/#{repo}", @yellow)
  defp color(input, color) when is_binary(input), do: "#{color}#{input}#{@reset}"

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
        Enum.map(pulls["items"], &get_repo_owner_from_url(&1["repository_url"]))

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
