defmodule Fork do
  @moduledoc """
  A module for mapping GitHub API sourced data to a struct representing a forked repository.
  """

  alias Tentacat.Repositories
  alias Tentacat.Users

  defstruct [
    :owner_repo,
    :link,
    :owner_username,
    :pulls,
    :issue_count,
    :parent
  ]

  def get_forks(client) do
    user = get_username(client)

    case Repositories.list_users(client, user) do
      {200, repos, _} ->
        repos
        |> Enum.filter(fn repo -> repo["fork"] end)
        |> Enum.map(fn repo ->
          link = repo["html_url"]
          user = repo["owner"]["login"]
          {owner, repo_name} = repo_owner_from_url(repo["full_name"])
          %Fork{owner_repo: {owner, repo_name}, link: link, owner_username: user}
        end)

      {status, body, _} ->
        raise "Failed to fetch repositories: status #{status}, #{inspect(body)}"
    end
  end

  def with_metadata(fork, client) do
    {owner, repo} = fork.owner_repo

    detail_task =
      Task.async(fn ->
        detail = get_repo_detail(fork, client)

        parent_data = Map.get(detail, "parent", %{})
        parent_owner_repo = repo_owner_from_url(Map.get(parent_data, "full_name", "/"))
        upstream_link = Map.get(parent_data, "html_url", "")

        upstream_pulls =
          get_pulls(parent_owner_repo, client)
          |> Enum.filter(fn pull -> pull["head"]["repo"]["full_name"] == "#{owner}/#{repo}" end)
          |> Enum.map(&pull_to_tuple/1)

        parent = %Fork{owner_repo: parent_owner_repo, link: upstream_link, pulls: upstream_pulls}
        issue_count = detail["open_issues_count"]
        {parent, issue_count}
      end)

    pulls = Enum.map(get_pulls(fork.owner_repo, client), &pull_to_tuple/1)

    {parent, issue_count} = Task.await(detail_task, :infinity)

    %Fork{
      fork
      | issue_count: issue_count,
        parent: parent,
        pulls: pulls
    }
  end

  def delete_fork({owner, repo}, client) do
    case Repositories.delete(client, owner, repo) do
      {204, _, _} -> :ok
      _ -> :error
    end
  end

  defp get_username(client) do
    case Users.me(client) do
      {200, info, _} -> info["login"]
      {status, body, _} -> raise "Failed to fetch user info: status #{status}, #{inspect(body)}"
    end
  end

  defp get_repo_detail(%Fork{owner_repo: {owner, repo}}, client) do
    case Repositories.repo_get(client, owner, repo) do
      {200, repo, _} -> repo
      _ -> %{}
    end
  end

  defp get_pulls({owner, repo}, client) do
    case Tentacat.Pulls.list(client, owner, repo) do
      {200, pulls, _} -> pulls
      _ -> []
    end
  end

  defp pull_to_tuple(%{title: title, html_url: link}), do: {title, link}

  defp repo_owner_from_url(url) do
    String.split(url, "/")
    |> Enum.take(-2)
    |> List.to_tuple()
  end
end
